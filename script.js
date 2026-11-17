/**
 * KL-06 Manager | Official Client-Side Web Script
 * Lead Architect & Developer: Kaushal Labana
 */

// Ecosystem Downloads Map (Direct Google Drive & GitHub Mirrors)
const PLATFORM_DATA = {
    android: {
        name: 'Android Package (APK Scheme v2)',
        fileName: 'KL-06-0.4.0-beta.1-android-debug-UNTESTED.zip',
        fileMeta: 'v0.4.0-beta.1 Build 6 • 1.04 MB • Signed APK v2',
        directUrl: 'https://drive.google.com/uc?id=1oXqdUSsI6cE-ZTB0RxvjzmHJvXhlPbQC&export=download',
        viewUrl: 'https://drive.google.com/file/d/1oXqdUSsI6cE-ZTB0RxvjzmHJvXhlPbQC/view?usp=sharing',
        sha256: 'bb7d99fd800934b7af0c19489e34ee97e79676d2728521c9693d4bc3a070a2b8',
        btnText: '⬇️ Download for Android (1.04 MB)'
    },
    mac: {
        name: 'macOS App Bundle (x86_64 / Rosetta)',
        fileName: 'KL-06 Manager 4.0 beta.zip',
        fileMeta: 'v0.4.0-beta.1 Build 6 • 195 KB • macOS 13+',
        directUrl: 'https://drive.google.com/uc?id=16SE_Z25itABzXg8p0aUrITkLr-2E-DVB&export=download',
        viewUrl: 'https://drive.google.com/file/d/16SE_Z25itABzXg8p0aUrITkLr-2E-DVB/view?usp=sharing',
        sha256: '88c721b11a660fe72cabfe72950085508b98e336fa8b62cbe21b2aab87c38941',
        btnText: '⬇️ Download for macOS (195 KB)'
    },
    windows: {
        name: 'Windows x64 Companion (.NET 10 + WebView2)',
        fileName: 'KL-06-0.4.0-beta.1-windows-x64-UNTESTED.zip',
        fileMeta: 'v0.4.0-beta.1 Build 6 • 553 KB • Windows 10/11 x64',
        directUrl: 'https://drive.google.com/uc?id=1legDzsIwv8oS00Ai3xHjCVu1-3wpWqsM&export=download',
        viewUrl: 'https://drive.google.com/file/d/1legDzsIwv8oS00Ai3xHjCVu1-3wpWqsM/view?usp=sharing',
        sha256: '9cf98f9ef1ced9761a2156c026154f51b3330b68babe1eb68c2965290797e55f',
        btnText: '⬇️ Download for Windows x64 (553 KB)'
    },
    ios: {
        name: 'iOS Mobile Companion (Swift / devicectl)',
        fileName: 'INSTALL-IOS.command & Xcode Project',
        fileMeta: 'v0.4.0-beta.1 Build 6 • iOS 16.0+ • Pure Swift',
        directUrl: 'https://github.com/Kaushal-snap/KL-06-Manager/blob/main/INSTALL-IOS.command',
        viewUrl: 'https://github.com/Kaushal-snap/KL-06-Manager/tree/main/ios',
        sha256: 'Build via devicectl / AltStore',
        btnText: '🛠️ View iOS Install Guide'
    },
    source: {
        name: 'Complete Source Code Archive',
        fileName: 'KL-06-0.4.0-beta.1-source-BUILD-READY.zip',
        fileMeta: 'v0.4.0-beta.1 Build 6 • 1.88 MB • 143 Clean Files',
        directUrl: 'https://drive.google.com/uc?id=1x_vQzspex16UQ7vJrxYdnC4nKhUEU-SW&export=download',
        viewUrl: 'https://drive.google.com/file/d/1x_vQzspex16UQ7vJrxYdnC4nKhUEU-SW/view?usp=sharing',
        sha256: 'd4d406699e22718f97441bd80e8e80b3191e8e3f8271c031228031a792579029',
        btnText: '⬇️ Download Full Source ZIP'
    }
};

// Initialize Application
document.addEventListener('DOMContentLoaded', () => {
    initDeviceDetection();
    initPlatformTabs();
    initPinGenerators();
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
