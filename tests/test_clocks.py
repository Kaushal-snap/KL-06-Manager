"""Pure synthetic ctypes clock adapters; never load a Mac/Windows library here."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

spec=importlib.util.spec_from_file_location('kl06_clock_test',Path(__file__).resolve().parents[1]/'companion/server.py')
S=importlib.util.module_from_spec(spec);spec.loader.exec_module(S)

class ClockAdapters(unittest.TestCase):
    def mac(self,numer=1,denom=1,result=0,ticks=123456789000):
        def base(pointer):pointer._obj.numer=numer;pointer._obj.denom=denom;return result
        return SimpleNamespace(mach_timebase_info=base,mach_absolute_time=lambda:ticks)
    def windows(self,frequency=10000000,ticks=123456789000,result=1,counter_result=1):
        def freq(pointer):pointer._obj.value=frequency;return result
        def counter(pointer):pointer._obj.value=ticks;return counter_result
        return SimpleNamespace(QueryPerformanceFrequency=freq,QueryPerformanceCounter=counter)
    def test_mac_boot_epoch_not_python39_relative_epoch(self):
        self.assertAlmostEqual(S._mac_uptime_clock(self.mac())(),123.456789)
    def test_mac_timebase_ratio(self):
        self.assertAlmostEqual(S._mac_uptime_clock(self.mac(numer=1000000000,denom=25000000,ticks=100000000))(),4)
    def test_mac_bad_timebase_fails_closed(self):
        for api in [self.mac(numer=0),self.mac(denom=0),self.mac(result=1)]:
            with self.assertRaises(S.Rejected):S._mac_uptime_clock(api)
    def test_windows_uses_qpc_not_gettickcount64_epoch(self):
        self.assertAlmostEqual(S._windows_uptime_clock(self.windows())(),12345.6789)
    def test_windows_bad_frequency_fails_closed(self):
        for api in [self.windows(frequency=0),self.windows(frequency=-1),self.windows(result=0)]:
            with self.assertRaises(S.Rejected):S._windows_uptime_clock(api)
    def test_windows_failed_counter_fails_closed(self):
        for api in [self.windows(counter_result=0),self.windows(ticks=-1)]:
            with self.assertRaises(S.Rejected):S._windows_uptime_clock(api)()

if __name__=='__main__':unittest.main()
