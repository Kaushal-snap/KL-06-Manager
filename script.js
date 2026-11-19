/**
 * KL-06 Manager | Official Client-Side Web Script
 * Lead Architect & Developer: Kaushal Labana
 */

// Ecosystem Downloads Map (Direct Google Drive & GitHub Mirrors)
const PLATFORM_DATA = {
    android: {
        name: 'Android Package (Dual v1 + v2 Signed)',
        fileName: 'KL-06-0.4.3-beta-android-debug-UNTESTED.zip',
        fileMeta: 'v0.4.3-beta Build 10 • 1.07 MB • Dual Signed (v1 JAR + v2 APK Scheme) • Android 8 to 17+',
        directUrl: 'https://drive.google.com/uc?id=1WEpT37FFFzY0LhfASUYggBbjswj1tv_p&export=download',
        viewUrl: 'https://drive.google.com/file/d/1WEpT37FFFzY0LhfASUYggBbjswj1tv_p/view?usp=sharing',
        apkDirectUrl: 'https://drive.google.com/uc?id=1XXwHOz3mpTpYtnMkoS-Hixi0GaYKOsyl&export=download',
        sha256: '95e02aeb2b7b877aa0ecb9009661573eabf5996fbea8c21f84734979f884afb7',
        btnText: '⬇️ Download for Android (1.07 MB)'
    },
    mac: {
        name: 'macOS App Bundle (x86_64 / Rosetta 2)',
        fileName: 'KL-06 Manager 4.3 beta.zip',
        fileMeta: 'v0.4.3-beta Build 10 • 196 KB • macOS 13.0+ (Ventura, Sonoma, Sequoia)',
        directUrl: 'https://drive.google.com/uc?id=1x88mqV6Z2bhgceUB-zRrHn3YOyhpH7bT&export=download',
        viewUrl: 'https://drive.google.com/file/d/1x88mqV6Z2bhgceUB-zRrHn3YOyhpH7bT/view?usp=sharing',
        sha256: 'b7bf54bbe9d7eaf320864d1231681868a1628c851a57d2fbf187a349cbec8240',
        btnText: '⬇️ Download for macOS (196 KB)'
    },
    windows: {
        name: 'Windows x64 Companion (.NET 10 + WebView2)',
        fileName: 'KL-06-0.4.3-beta-windows-x64-UNTESTED.zip',
        fileMeta: 'v0.4.3-beta Build 10 • 561 KB • Windows 7 SP1, 8, 8.1, 10, 11',
        directUrl: 'https://drive.google.com/uc?id=1u3iLwHS-_bTWk1SuEFDy9YiIpZH-8l50&export=download',
        viewUrl: 'https://drive.google.com/file/d/1u3iLwHS-_bTWk1SuEFDy9YiIpZH-8l50/view?usp=sharing',
        sha256: '6cf5a99dcd3832b452a969d296ce9d28709898874424058d03a9f4eb188d7a9b',
        btnText: '⬇️ Download for Windows x64 (561 KB)'
    },
    ios: {
        name: 'iOS Mobile Companion (Swift / devicectl)',
        fileName: 'INSTALL-IOS.command & Xcode Project',
        fileMeta: 'v0.4.3-beta Build 10 • iOS 16.0+ (iOS 16, 17, 18+) • Pure Swift',
        directUrl: 'https://github.com/Kaushal-snap/KL-06-Manager/blob/main/INSTALL-IOS.command',
        viewUrl: 'https://github.com/Kaushal-snap/KL-06-Manager/tree/main/ios',
        sha256: 'Build via devicectl / AltStore / Xcode',
        btnText: '🛠️ View iOS Install Guide'
    },
    source: {
        name: 'Complete Source Code Archive',
        fileName: 'KL-06-0.4.3-beta-source-BUILD-READY.zip',
        fileMeta: 'v0.4.3-beta Build 10 • 2.02 MB • 143 Clean Files',
        directUrl: 'https://drive.google.com/uc?export=download&id=1onxh-6QO060tofPmNpKmXXdap7IRDWoP',
        viewUrl: 'https://drive.google.com/file/d/1onxh-6QO060tofPmNpKmXXdap7IRDWoP/view',
        sha256: 'e2aea521137d1654f8c84fe4892bd3a1b51e9890d88bd873e8cc65131e46a550',
        btnText: '⬇️ Download Full Source ZIP'
    }
};

// Ecosystem Downloads Map - Version 0.4.1-beta (Previous Stable Release Archive)
const PLATFORM_DATA_V041 = {
    android: {
        name: 'Android Package (v0.4.1-beta)',
        fileName: 'KL-06-0.4.1-beta-android-debug-UNTESTED.zip',
        fileMeta: 'v0.4.1-beta Build 8 • 1.07 MB • Dual Signed (v1 JAR + v2 APK Scheme)',
        directUrl: 'https://drive.google.com/uc?id=1zRWT9XC2CaTBxv5As041ZyBxCeyJ9Zg2&export=download',
        viewUrl: 'https://drive.google.com/file/d/1zRWT9XC2CaTBxv5As041ZyBxCeyJ9Zg2/view?usp=sharing',
        sha256: '9f6f8e1bdb38109a53e5056629f9a567ba0e584b4e296e20af2b66a5e545b56c',
        btnText: '⬇️ Download v0.4.1 for Android (1.07 MB)'
    },
    mac: {
        name: 'macOS App Bundle (v0.4.1-beta)',
        fileName: 'KL-06 Manager 4.1 beta.zip',
        fileMeta: 'v0.4.1-beta Build 8 • 196 KB • macOS 13.0+ (Ventura, Sonoma, Sequoia)',
        directUrl: 'https://drive.google.com/uc?id=10NRu1ai2W0TTvjEgbM0wNqPhsFqFBq5X&export=download',
        viewUrl: 'https://drive.google.com/file/d/10NRu1ai2W0TTvjEgbM0wNqPhsFqFBq5X/view?usp=sharing',
        sha256: '8b92e8da62dfebbbcfb8b34ab4b81006e0406a9b28377629fc38e2bd02db13e0',
        btnText: '⬇️ Download v0.4.1 for macOS (196 KB)'
    },
    windows: {
        name: 'Windows x64 Companion (v0.4.1-beta)',
        fileName: 'KL-06-0.4.1-beta-windows-x64-UNTESTED.zip',
        fileMeta: 'v0.4.1-beta Build 8 • 553 KB • Windows 7 SP1, 8, 8.1, 10, 11',
        directUrl: 'https://drive.google.com/uc?id=1DAufzzBph0snQ3mDZ3c3Z1ulRTmvExxR&export=download',
        viewUrl: 'https://drive.google.com/file/d/1DAufzzBph0snQ3mDZ3c3Z1ulRTmvExxR/view?usp=sharing',
        sha256: '3df20f1489ee61bb9e500db640e35ad333bfef2e0c66276f3766c897eff9474c',
        btnText: '⬇️ Download v0.4.1 for Windows (553 KB)'
    },
    ios: {
        name: 'iOS Mobile Companion (v0.4.1-beta)',
        fileName: 'INSTALL-IOS.command & Xcode Project',
        fileMeta: 'v0.4.1-beta Build 8 • iOS 16.0+ (iOS 16, 17, 18+) • Pure Swift',
        directUrl: 'https://github.com/Kaushal-snap/KL-06-Manager/blob/main/INSTALL-IOS.command',
        viewUrl: 'https://github.com/Kaushal-snap/KL-06-Manager/tree/main/ios',
        sha256: 'Build via devicectl / AltStore / Xcode',
        btnText: '🛠️ View iOS Install Guide'
    },
    source: {
        name: 'Complete Source Code Archive (v0.4.1-beta)',
        fileName: 'KL-06-0.4.1-beta-source-BUILD-READY.zip',
        fileMeta: 'v0.4.1-beta Build 8 • 1.88 MB • 143 Clean Files',
        directUrl: 'https://drive.google.com/uc?id=1DCYi-5CN7OrMYgMZ5bPY8PaNNu6pUcPC&export=download',
        viewUrl: 'https://drive.google.com/file/d/1DCYi-5CN7OrMYgMZ5bPY8PaNNu6pUcPC/view?usp=sharing',
        sha256: '328662e100a59f027de8c778738cee88fc0416f95510a9d663a85bb3f7be3073',
        btnText: '⬇️ Download v0.4.1 Full Source ZIP'
    }
};

let currentSelectedVersion = '0.4.3';

function switchVersionDisplay(version) {
    currentSelectedVersion = version;
    const btn043 = document.getElementById('btn-ver-043') || document.getElementById('btn-ver-042');
    const btn041 = document.getElementById('btn-ver-041');
    const archiveSection = document.getElementById('archive-041-section');
    const latestSection = document.getElementById('latest-042-grid');

    if (version === '0.4.1') {
        if (btn041) btn041.classList.add('active');
        if (btn043) btn043.classList.remove('active');
        if (archiveSection) archiveSection.style.display = 'grid';
        if (latestSection) latestSection.style.display = 'none';
        showToast("Switched to Version 0.4.1-beta Archive Downloads.");
    } else {
        if (btn043) btn043.classList.add('active');
        if (btn041) btn041.classList.remove('active');
        if (archiveSection) archiveSection.style.display = 'none';
        if (latestSection) latestSection.style.display = 'grid';
        showToast("Showing Version 0.4.3-beta (Latest Release).");
    }
}

// Initialize Application
document.addEventListener('DOMContentLoaded', () => {
    initDeviceDetection();
    initPlatformTabs();
    initPinGenerators();
    initPriorityMockup();
    initMobileNav();
    initSmoothScroll();
});

/**
 * Detect Visitor's Device / Operating System
 */
function initDeviceDetection() {
    const userAgent = navigator.userAgent || navigator.vendor || window.opera || '';
    const platform = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '';

    let detectedKey = 'mac'; // Default fallback

    if (/android/i.test(userAgent)) {
        detectedKey = 'android';
    } else if (/iPad|iPhone|iPod/.test(userAgent) || (platform === 'MacIntel' && navigator.maxTouchPoints > 1)) {
        detectedKey = 'ios';
    } else if (/Mac|Macintosh|MacIntel/i.test(userAgent) || /Mac/i.test(platform)) {
        detectedKey = 'mac';
    } else if (/Win|Windows/i.test(userAgent) || /Win/i.test(platform)) {
        detectedKey = 'windows';
    } else if (/Linux/i.test(userAgent)) {
        detectedKey = 'source';
    }

    const info = PLATFORM_DATA[detectedKey];
    if (!info) return;

    const osNameEl = document.getElementById('detected-os-name');
    const fileNameEl = document.getElementById('detected-file-name');
    const fileMetaEl = document.getElementById('detected-file-meta');
    const dlBtn = document.getElementById('detected-download-btn');
    const btnText = document.getElementById('detected-btn-text');

    if (osNameEl) osNameEl.textContent = info.name;
    if (fileNameEl) fileNameEl.textContent = info.fileName;
    if (fileMetaEl) fileMetaEl.textContent = info.fileMeta;
    if (btnText) btnText.textContent = info.btnText;

    if (dlBtn) {
        dlBtn.href = info.directUrl;
        dlBtn.setAttribute('data-target-platform', detectedKey);
    }
}

/**
 * Filter Download Cards by Platform Tab
 */
function initPlatformTabs() {
    const tabs = document.querySelectorAll('.tab-btn');
    const cards = document.querySelectorAll('.platform-card');

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');

            const filter = tab.getAttribute('data-filter');

            cards.forEach(card => {
                const cardPlatform = card.getAttribute('data-platform');
                if (filter === 'all' || cardPlatform === filter) {
                    card.style.display = 'flex';
                } else {
                    card.style.display = 'none';
                }
            });
        });
    });
}

/**
 * 6-Digit PIN Generator Simulation
 */
function initPinGenerators() {
    const heroBtn = document.getElementById('btn-hero-gen-pin');
    const demoBtn = document.getElementById('btn-gen-demo-pin');

    if (heroBtn) {
        heroBtn.addEventListener('click', generateHeroPin);
    }
    if (demoBtn) {
        demoBtn.addEventListener('click', generateDemoPin);
    }

    // Auto-update countdown timer simulation
    let secondsLeft = 60;
    setInterval(() => {
        secondsLeft--;
        if (secondsLeft <= 0) {
            secondsLeft = 60;
            generateHeroPin();
            generateDemoPin();
        }

        const heroTimer = document.getElementById('hero-pin-timer');
        const demoTimer = document.getElementById('demo-pin-timer');
        if (heroTimer) heroTimer.textContent = `Expires in ${secondsLeft}s`;
        if (demoTimer) demoTimer.textContent = `Active (${secondsLeft}s)`;
    }, 1000);
}

function generateHeroPin() {
    const pin = Math.floor(100000 + Math.random() * 900000).toString();
    const boxes = document.getElementById('hero-pin-boxes');
    if (boxes) {
        boxes.innerHTML = pin.split('').map(digit => `<span>${digit}</span>`).join('');
    }
}

function generateDemoPin() {
    const pin = Math.floor(100000 + Math.random() * 900000).toString();
    const formatted = `${pin.slice(0, 3)} ${pin.slice(3)}`;
    const demoPin = document.getElementById('demo-pin-code');
    if (demoPin) demoPin.textContent = formatted;
}

/**
 * Interactive Auto-Pair Consent Modal Simulation
 */
function showPeerModal(peerName, subText, ip) {
    const modal = document.getElementById('consent-modal');
    const nameEl = document.getElementById('consent-peer-name');
    const subEl = document.getElementById('consent-peer-sub');
    const pinEl = document.getElementById('consent-pin-display');

    if (nameEl) nameEl.textContent = peerName;
    if (subEl) subEl.textContent = `Nearby on ${subText} (${ip})`;
    if (pinEl) pinEl.textContent = Math.floor(100000 + Math.random() * 900000).toString();

    if (modal) modal.classList.add('open');
}

function triggerConsentModalDemo() {
    showPeerModal('Kaushal’s VivoBook (macOS)', 'Wi-Fi 5GHz', '192.168.1.100');
}

function closeConsentModal(accepted) {
    const modal = document.getElementById('consent-modal');
    if (modal) modal.classList.remove('open');

    if (accepted) {
        alert('✅ Connection Accepted! Devices are now securely paired via 6-digit mutual PIN.');
    }
}

/**
 * Clipboard Copy Utility
 */
function copyText(text, btnElement) {
    if (!navigator.clipboard) {
        const temp = document.createElement('textarea');
        temp.value = text;
        document.body.appendChild(temp);
        temp.select();
        document.execCommand('copy');
        document.body.removeChild(temp);
    } else {
        navigator.clipboard.writeText(text);
    }

    if (btnElement) {
        const originalText = btnElement.innerText;
        btnElement.innerText = '✓ Copied!';
        btnElement.style.color = '#10b981';
        btnElement.style.borderColor = '#10b981';

        setTimeout(() => {
            btnElement.innerText = originalText;
            btnElement.style.color = '';
            btnElement.style.borderColor = '';
        }, 2000);
    }
}

/**
 * Lightbox Gallery Viewer
 */
function openLightbox(imgSrc, caption) {
    const lightbox = document.getElementById('lightbox');
    const img = document.getElementById('lightbox-img');
    const cap = document.getElementById('lightbox-caption');

    if (img) img.src = imgSrc;
    if (cap) cap.textContent = caption;
    if (lightbox) lightbox.classList.add('open');
}

function closeLightbox() {
    const lightbox = document.getElementById('lightbox');
    if (lightbox) lightbox.classList.remove('open');
}

/**
 * Mobile Navigation Drawer Toggle
 */
function initMobileNav() {
    const toggle = document.getElementById('mobile-toggle');
    const menu = document.getElementById('nav-menu');

    if (toggle && menu) {
        toggle.addEventListener('click', () => {
            menu.classList.toggle('open');
        });

        // Close on link click
        menu.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => {
                menu.classList.remove('open');
            });
        });
    }
}

/**
 * Smooth Scrolling for Anchor Links
 */
function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            const href = this.getAttribute('href');
            if (href === '#' || href === '') return;
            const target = document.querySelector(href);
            if (target) {
                e.preventDefault();
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });
}

/**
 * Progressive OS Version & Feature Matrix Explorer
 */
const PROGRESSIVE_FEATURES = {
    'android-8-9': {
        title: 'Android 8.0 Oreo & 9.0 Pie (API 26–28)',
        badge: 'Baseline Minimum Supported',
        accent: '#10b981',
        highlights: [
            '🛡️ Standard LAN peer discovery with zero cloud telemetry',
            '🔊 In-app media volume scalar and window brightness override',
            '📊 Live battery charge, memory usage, and storage telemetry',
            '🌐 Isolated Android System WebView bridge with restricted origin',
            '📦 Dual v1 (JAR) and v2 APK signature verification'
        ]
    },
    'android-10-11': {
        title: 'Android 10 & Android 11 (API 29–30)',
        badge: 'Dark Theme & Hotspot Tethering',
        accent: '#06b6d4',
        highlights: [
            '🌙 Automatic System Dark Theme synchronization (prefers-color-scheme)',
            '📡 Wi-Fi LocalOnlyHotspot direct device-to-device wireless sharing',
            '📁 Scoped Storage compliance with isolated internal app sandbox',
            '⚡ 64-bit ART runtime memory performance boost',
            '🔒 Enforced APK Signature Scheme v2 block verification'
        ]
    },
    'android-12': {
        title: 'Android 12 & 12L (API 31–32)',
        badge: 'Material You & Bluetooth LE Radar',
        accent: '#8b5cf6',
        highlights: [
            '🎨 Material You dynamic color palette integration matching system wallpaper',
            '🛰️ Bluetooth Low Energy (BLE) beacon scanner for instant radar peer detection',
            '✨ System splash screen API with smooth animated launch transitions',
            '🛡️ Strict android:exported="true" component isolation for Android 12 safety',
            '🔕 Microphone & camera privacy indicator compatibility'
        ]
    },
    'android-13': {
        title: 'Android 13 Tiramisu (API 33) — Tested & Verified',
        badge: 'Auto-Pair Consent Modal & Dual v1/v2 Fixed',
        accent: '#ec4899',
        highlights: [
            '✅ PackageParser Installation Fix: Dual v1 (JAR) + v2 signing with REL release codename',
            '📁 Priority 1 File Sharing: Instant AirDrop / Quick Share radar and dropzone',
            '🔔 Runtime POST_NOTIFICATIONS transfer progress alerts',
            '💬 Auto-Pair incoming consent prompt dialog with Accept & Connect',
            '🔒 6-digit mutual PIN confirmation with 60-second validity window',
            '💾 Scoped MediaStore auto-saver exporting logs to Download/KL-06/logs/'
        ]
    },
    'android-14-15': {
        title: 'Android 14 & 15 (API 34–35)',
        badge: 'Predictive Back & Multi-Gigabit LAN',
        accent: '#6366f1',
        highlights: [
            '🔄 Predictive back gesture navigation with smooth swipe-to-dismiss preview',
            '🚀 Foreground dataSync service type for reliable background multi-gigabyte transfers',
            '📂 WebChromeClient onShowFileChooser integration for native file choosing',
            '📶 Multi-gigabit chunked LAN streaming with zero TCP packet stalls',
            '📱 Inbuilt Mobile Controls (Priority 2): Direct volume, brightness & Keep-Awake',
            '🔋 Advanced standby power management with zero battery drain'
        ]
    },
    'android-16-17': {
        title: 'Android 16 & Android 17+ (API 36+)',
        badge: '16KB Page Size & Wi-Fi 7 Mesh',
        accent: '#f59e0b',
        highlights: [
            '⚡ 16KB memory page size architecture alignment for next-gen Android kernels',
            '🌐 Wi-Fi 7 Multi-Link Operation (MLO) high-speed P2P wireless mesh',
            '📐 Edge-to-edge window insets integration with transparent system bars',
            '⚙️ Priority 3 "Etc" PC tools: Mac & Windows fan monitor and HWiNFO charts',
            '🛡️ Advanced post-quantum TLS cryptography cipher support',
            '📱 Ultra-low latency multi-device screen & audio sync'
        ]
    },
    'ios-16': {
        title: 'iOS 16 (Minimum Baseline)',
        badge: 'Isolated WKWebView & TLS Pinning',
        accent: '#06b6d4',
        highlights: [
            '🛡️ Zero ATS bypass: strict main-frame WKWebView isolated bridge',
            '🔒 Per-connection TLS certificate pinning with public Swift APIs',
            '📂 UIDocumentPickerDelegate native file selection and AirDrop streaming',
            '📱 Lock Screen live hardware telemetry widgets',
            '⚡ Pure Swift 5.0 compilation with devicectl and Xcode support'
        ]
    },
    'ios-17-18': {
        title: 'iOS 17 & iOS 18+',
        badge: 'Dynamic Island & StandBy Mode',
        accent: '#ec4899',
        highlights: [
            '🏝️ Dynamic Island live file transfer progress and transfer speed tracker',
            '⏰ StandBy Mode horizontal bedside companion dashboard',
            '🤝 Seamless AirDrop mesh companion pairing with nearby Android & Mac peers',
            '🛠️ Native pickShareFile and openAppSettings bridge handlers in Swift',
            '✨ Interactive home screen widgets with one-tap toggle'
        ]
    },
    'macos-13': {
        title: 'macOS 13 Ventura (Minimum Baseline)',
        badge: 'Native AppKit & Hardware Governance',
        accent: '#6366f1',
        highlights: [
            '💻 Native Menu Bar item with instant status and F13 PrtSc hotkey toggle',
            '☀️ OLED and DPCD hardware brightness scalar without driver overwrites',
            '🪟 Stage Manager multi-window companion integration',
            '🌪️ Safe read-only fan RPM monitor (zero SMC/EC write risks)',
            '⚡ Zero-flicker persistent DOM shell architecture'
        ]
    },
    'macos-14-15': {
        title: 'macOS 14 Sonoma & macOS 15 Sequoia',
        badge: 'Interactive Widgets & Window Tiling',
        accent: '#8b5cf6',
        highlights: [
            '🖥️ Interactive Desktop Widgets for live CPU, battery, and fan status',
            '🎮 Sonoma Game Mode compatibility with process priority tuning',
            '📈 HWiNFO CSV sensor history parser with interactive canvas graphing',
            '📐 Sequoia native window tiling and snap layouts',
            '🔒 macOS Gatekeeper and notarization compliance'
        ]
    },
    'win-7-8': {
        title: 'Windows 7 SP1, Windows 8, Windows 8.1',
        badge: 'Classic Aero Desktop Companion',
        accent: '#10b981',
        highlights: [
            '🪟 Full Aero Glass and Classic Windows desktop integration',
            '⚙️ Lightweight .NET Desktop Runtime host with minimal RAM footprint',
            '📁 Secure LAN file transfer and pairing with mobile devices',
            '🛡️ Windows 7 SP1 compatibility manifest with full OS GUID mapping'
        ]
    },
    'win-10-11': {
        title: 'Windows 10 & Windows 11',
        badge: 'WebView2, Mica Material & High-DPI',
        accent: '#3b82f6',
        highlights: [
            '🌐 Evergreen Microsoft Edge WebView2 runtime integration',
            '💎 Windows 11 Mica and Acrylic translucent materials',
            '📐 Per-Monitor v2 dynamic high-DPI scaling across multi-monitor setups',
            '💻 Remote PC controls: lock, sleep, and master volume slider from phone',
            '🔔 Action Center toast notifications with real-time transfer progress'
        ]
    }
};

function selectProgressiveVersion(key) {
    const data = PROGRESSIVE_FEATURES[key];
    if (!data) return;

    document.querySelectorAll('.ver-pill').forEach(pill => {
        if (pill.getAttribute('data-ver') === key) {
            pill.classList.add('active');
        } else {
            pill.classList.remove('active');
        }
    });

    const titleEl = document.getElementById('prog-title');
    const badgeEl = document.getElementById('prog-badge');
    const listEl = document.getElementById('prog-list');

    if (titleEl) titleEl.textContent = data.title;
    if (badgeEl) {
        badgeEl.textContent = data.badge;
        badgeEl.style.borderColor = data.accent;
        badgeEl.style.color = data.accent;
    }
    if (listEl) {
        listEl.innerHTML = data.highlights.map(item => `<li>${item}</li>`).join('');
    }
}

/**
 * Priority Mockup Interactive Switcher (v0.4.2-beta)
 */
const PRIORITY_MOCKUP_DATA = {
    1: {
        title: "Priority 1: Instant File Sharing & AirDrop Hub",
        desc: "When opening KL-06 Manager on mobile, you land directly on the File Sharing radar. Nearby companions running on Mac and Windows are discovered instantly on UDP/TLS port 8766. Drag-and-drop or use the file chooser for instant high-speed streaming with SHA-256 chunk validation.",
        tags: ["UDP Port 8766", "Direct TLS P2P", "Document Picker", "SHA-256 Validation"],
        bullets: [
            "📡 Automatic discovery of nearby Mac and Windows companions on Wi-Fi or Hotspot",
            "📥 One-tap file receiving with consent dialog confirmation",
            "🔄 Multi-gigabit transfer rate with real-time ETA and byte progress indicator"
        ],
        screenHtml: `
            <div style="text-align:center;margin-bottom:0.5rem">
                <span class="pulse-dot" style="display:inline-block;margin-right:6px"></span>
                <strong style="color:#60a5fa;font-size:0.85rem">P2P Radar Scanner Active</strong>
            </div>
            <div class="demo-dropzone-box" onclick="simulateFileUpload()" style="cursor:pointer">
                <div style="font-size:1.8rem">📂</div>
                <strong style="font-size:0.9rem;color:#f8fafc;display:block;margin-top:4px">Tap or Drop Files to Share</strong>
                <p>Using WebChromeClient / DocumentPicker • Up to 10 GB</p>
            </div>
            <div style="background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.08);border-radius:12px;padding:0.75rem">
                <div style="display:flex;justify-content:space-between;font-size:0.8rem">
                    <span><strong>Active:</strong> 4K_B-Roll_Clip.mov</span>
                    <span style="color:#34d399">78 MB/s</span>
                </div>
                <div class="demo-progress-bar">
                    <div class="demo-progress-fill" id="demo-share-fill" style="width: 68%;"></div>
                </div>
                <div style="display:flex;justify-content:space-between;font-size:0.72rem;color:#94a3b8;margin-top:4px">
                    <span>Sending to Kaushal's VivoBook</span>
                    <span id="demo-share-percent">68% (1.2 GB / 1.8 GB)</span>
                </div>
            </div>
        `
    },
    2: {
        title: "Priority 2: Inbuilt Mobile Device Controls",
        desc: "Direct on-device hardware governance. Adjust media volume and screen brightness smoothly with tactile sliders, enable Keep-Awake to protect long file transfers, inspect battery statistics, and export diagnostics directly to public Downloads.",
        tags: ["Volume Scalar", "Display Brightness", "Keep-Awake Timer", "MediaStore Auto-Save"],
        bullets: [
            "🔊 Direct in-app media volume override without hardware buttons",
            "☀️ Screen brightness adjustment slider for daylight or night reading",
            "☕ Bounded Keep-Awake lock preventing screen sleep during massive transfers",
            "💾 One-click diagnostic report exporter to Download/KL-06/logs via MediaStore"
        ],
        screenHtml: `
            <div style="display:flex;flex-direction:column;gap:0.75rem">
                <div class="demo-slider-row">
                    <label><span>🔊 Phone Media Volume</span><strong id="vol-val">75%</strong></label>
                    <input type="range" min="0" max="100" value="75" oninput="document.getElementById('vol-val').textContent=this.value+'%'">
                </div>
                <div class="demo-slider-row">
                    <label><span>☀️ Screen Brightness</span><strong id="bri-val">82%</strong></label>
                    <input type="range" min="10" max="100" value="82" oninput="document.getElementById('bri-val').textContent=this.value+'%'">
                </div>
                <div style="display:flex;justify-content:space-between;align-items:center;background:rgba(255,255,255,0.04);padding:0.6rem 0.8rem;border-radius:10px;border:1px solid rgba(255,255,255,0.08)">
                    <span style="font-size:0.82rem">☕ Screen Keep-Awake</span>
                    <span class="badge-tag" style="background:#10b981;color:#fff">ACTIVE (10m)</span>
                </div>
                <div style="display:flex;justify-content:space-between;align-items:center;background:rgba(255,255,255,0.04);padding:0.6rem 0.8rem;border-radius:10px;border:1px solid rgba(255,255,255,0.08)">
                    <span style="font-size:0.82rem">🔋 Battery Telemetry</span>
                    <span style="font-size:0.82rem;color:#34d399">88% (Healthy)</span>
                </div>
                <button class="btn btn-outline btn-sm" onclick="showToast('Diagnostic log auto-saved to Download/KL-06/logs/KL-06-Report.log via Android MediaStore!')" style="width:100%;font-size:0.78rem">
                    💾 Export Diagnostics to Download/KL-06
                </button>
            </div>
        `
    },
    3: {
        title: "Priority 3: \"Etc\" PC & Mac Hardware Tools",
        desc: "Specialized laptop and desktop companion features are cleanly housed under Etc. Mobile users never face screen clutter, yet full access to fan telemetry, HWiNFO history charts, and remote PC companion controls is just one tap away.",
        tags: ["Mac / Win Fans", "HWiNFO CSV Graph", "System Tweaks", "Remote PC Control"],
        bullets: [
            "🌪️ Non-invasive read-only fan RPM monitoring with aging cache protection",
            "📈 Interactive HWiNFO sensor CSV parser with dynamic HTML5 canvas chart",
            "🎛️ Reversible Dock, Finder, and system tweaks with atomic restore journal",
            "💻 Remote PC control: lock, sleep, and master laptop audio slider"
        ],
        screenHtml: `
            <div style="display:flex;flex-direction:column;gap:0.7rem">
                <div style="background:rgba(255,255,255,0.04);padding:0.6rem 0.8rem;border-radius:10px;border:1px solid rgba(255,255,255,0.08);display:flex;justify-content:space-between;align-items:center">
                    <div>
                        <div style="font-size:0.75rem;color:#94a3b8">Mac / Win Fan Telemetry</div>
                        <strong style="color:#60a5fa;font-size:0.95rem">2,420 RPM</strong>
                    </div>
                    <span class="badge-tag" style="background:rgba(59,130,246,0.2);color:#60a5fa">READ-ONLY</span>
                </div>
                <div style="background:rgba(255,255,255,0.04);padding:0.6rem 0.8rem;border-radius:10px;border:1px solid rgba(255,255,255,0.08)">
                    <div style="display:flex;justify-content:space-between;font-size:0.75rem;margin-bottom:4px">
                        <span style="color:#94a3b8">HWiNFO Sensor History (CPU Temp)</span>
                        <span style="color:#fbbf24">52°C</span>
                    </div>
                    <div style="height:36px;background:rgba(0,0,0,0.3);border-radius:6px;display:flex;align-items:flex-end;gap:3px;padding:3px">
                        <div style="height:40%;flex-grow:1;background:#38bdf8;border-radius:2px"></div>
                        <div style="height:48%;flex-grow:1;background:#38bdf8;border-radius:2px"></div>
                        <div style="height:55%;flex-grow:1;background:#fbbf24;border-radius:2px"></div>
                        <div style="height:62%;flex-grow:1;background:#fbbf24;border-radius:2px"></div>
                        <div style="height:50%;flex-grow:1;background:#38bdf8;border-radius:2px"></div>
                        <div style="height:58%;flex-grow:1;background:#fbbf24;border-radius:2px"></div>
                    </div>
                </div>
                <div style="display:grid;grid-template-columns:1fr 1fr;gap:0.5rem">
                    <button class="btn btn-outline btn-sm" onclick="showToast('Sent remote lock signal to paired PC!')" style="font-size:0.72rem">🔒 Lock Laptop</button>
                    <button class="btn btn-outline btn-sm" onclick="showToast('Sent remote sleep signal to paired PC!')" style="font-size:0.72rem">💤 Sleep Laptop</button>
                </div>
            </div>
        `
    },
    4: {
        title: "Priority 4: Verified Safety & Security Invariants",
        desc: "Guaranteed system preservation. No kernel tampering, no unauthorized persistent modifications, no broad storage or camera permissions, and zero tracking servers.",
        tags: ["Dual Signed v1+v2", "Zero Cloud Telemetry", "Atomic Restore Journal", "4KB Page Aligned"],
        bullets: [
            "🔒 6-digit mutual PIN code with 60-second monotonic expiry window",
            "📦 Dual APK Signature Scheme v1 (JAR) + v2 with 4KB page alignment",
            "🛡️ 20 strictly declared permissions; zero broad storage, mic, or camera access",
            "🔕 100% offline local network; zero data transmission to external servers"
        ],
        screenHtml: `
            <div style="display:flex;flex-direction:column;gap:0.6rem">
                <div style="background:rgba(16,185,129,0.08);border:1px solid rgba(16,185,129,0.25);border-radius:10px;padding:0.6rem 0.8rem;display:flex;align-items:center;gap:8px">
                    <span style="color:#34d399">✅</span>
                    <div style="font-size:0.78rem"><strong>Dual v1 + v2 Signed:</strong> RSA-2048 persistent key lineage</div>
                </div>
                <div style="background:rgba(16,185,129,0.08);border:1px solid rgba(16,185,129,0.25);border-radius:10px;padding:0.6rem 0.8rem;display:flex;align-items:center;gap:8px">
                    <span style="color:#34d399">✅</span>
                    <div style="font-size:0.78rem"><strong>Zero Cloud Telemetry:</strong> Offline LAN only</div>
                </div>
                <div style="background:rgba(16,185,129,0.08);border:1px solid rgba(16,185,129,0.25);border-radius:10px;padding:0.6rem 0.8rem;display:flex;align-items:center;gap:8px">
                    <span style="color:#34d399">✅</span>
                    <div style="font-size:0.78rem"><strong>Scoped Storage:</strong> MediaStore public Download auto-save</div>
                </div>
                <div style="background:rgba(16,185,129,0.08);border:1px solid rgba(16,185,129,0.25);border-radius:10px;padding:0.6rem 0.8rem;display:flex;align-items:center;gap:8px">
                    <span style="color:#34d399">✅</span>
                    <div style="font-size:0.78rem"><strong>Read-Only Fan Safety:</strong> Zero SMC/EC write risks</div>
                </div>
            </div>
        `
    }
};

function initPriorityMockup() {
    switchPriorityMockup(1);
}

function switchPriorityMockup(id) {
    const data = PRIORITY_MOCKUP_DATA[id];
    if (!data) return;

    // Update switcher buttons
    document.querySelectorAll('.p-tab-btn').forEach(btn => {
        if (btn.getAttribute('data-mockup') === id.toString()) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });

    // Update phone bottom nav items
    for (let i = 1; i <= 4; i++) {
        const navItem = document.getElementById(`pnav-${i}`);
        if (navItem) {
            if (i === id) navItem.classList.add('active');
            else navItem.classList.remove('active');
        }
    }

    // Update left description
    const titleEl = document.getElementById('mockup-detail-title');
    const descEl = document.getElementById('mockup-detail-desc');
    const tagsEl = document.getElementById('mockup-detail-tags');
    const listEl = document.getElementById('mockup-detail-list');
    const screenEl = document.getElementById('mockup-screen-content');

    if (titleEl) titleEl.textContent = data.title;
    if (descEl) descEl.textContent = data.desc;
    if (tagsEl) {
        tagsEl.innerHTML = data.tags.map(tag => `<span>${tag}</span>`).join('');
    }
    if (listEl) {
        listEl.innerHTML = data.bullets.map(b => `<li>${b}</li>`).join('');
    }
    if (screenEl) {
        screenEl.innerHTML = data.screenHtml;
    }
}

function simulateFileUpload() {
    showToast("Simulating file drop: 4K_B-Roll_Clip.mov selected via DocumentPicker!");
    const fill = document.getElementById('demo-share-fill');
    const pct = document.getElementById('demo-share-percent');
    if (fill && pct) {
        let p = 10;
        fill.style.width = p + '%';
        pct.textContent = p + '% (0.2 GB / 1.8 GB)';
        const interval = setInterval(() => {
            p += 15;
            if (p >= 100) {
                p = 100;
                fill.style.width = '100%';
                pct.textContent = '100% Transfer Complete (Verified SHA-256)!';
                clearInterval(interval);
                showToast("File transfer completed successfully to Kaushal's VivoBook!");
            } else {
                fill.style.width = p + '%';
                pct.textContent = p + '% (' + (p * 0.018).toFixed(1) + ' GB / 1.8 GB)';
            }
        }, 200);
    }
}

function showToast(message) {
    let toast = document.getElementById('global-toast');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'global-toast';
        toast.style.cssText = 'position:fixed;bottom:24px;left:50%;transform:translateX(-50%);background:#0f172a;color:#f8fafc;padding:12px 24px;border-radius:9999px;border:1px solid rgba(99,102,241,0.5);box-shadow:0 10px 30px rgba(0,0,0,0.5);font-size:0.88rem;z-index:99999;transition:all 0.3s ease;opacity:0;pointer-events:none;';
        document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.style.opacity = '1';
    toast.style.transform = 'translateX(-50%) translateY(0)';
    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(-50%) translateY(10px)';
    }, 3500);
}
