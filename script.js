// GitHub Repo Config
const GITHUB_REPO = 'Kaushal-snap/KL-06-Manager';
const GITHUB_API = `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`;

// Download links - update these with your actual GitHub Release asset URLs
const downloadLinks = {
    mac: '#',
    windows: '#',
    android: '#',
    ios: '#'
};

// Version display elements
const versionElements = document.querySelectorAll('.version-tag');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    const yearEl = document.getElementById('year');
    if (yearEl) yearEl.textContent = new Date().getFullYear();
    
    loadLatestRelease();
    initDownloadButtons();
    initSmoothScroll();
});

// Fetch latest release from GitHub API
async function loadLatestRelease() {
    try {
        const response = await fetch(GITHUB_API, {
            headers: {
                'Accept': 'application/vnd.github+json',
            }
        });
        
        if (!response.ok) {
            throw new Error('Failed to fetch releases');
        }
        
        const release = await response.json();
        const version = release.tag_name || 'v1.0.0';
        
        // Update version tags on page
        document.querySelectorAll('.version-tag').forEach(tag => {
            tag.textContent = version;
        });
        
        // Parse assets from release
        const assets = release.assets || [];
        const assetMap = {};
        
        assets.forEach(asset => {
            const name = asset.name.toLowerCase();
            const url = asset.browser_download_url;
            
            if (name.includes('mac') || name.includes('dmg') || name.includes('pkg')) {
                assetMap.mac = url;
            } else if (name.includes('win') || name.includes('exe') || name.includes('msi')) {
                assetMap.windows = url;
            } else if (name.includes('android') || name.includes('apk')) {
                assetMap.android = url;
            } else if (name.includes('ios') || name.includes('iphone')) {
                assetMap.ios = url;
            }
        });
        
        // Update download links
        Object.assign(downloadLinks, assetMap);
        
        // Update update list
        const updateList = document.getElementById('update-list');
        if (updateList && release.body) {
            const updateItem = document.createElement('div');
            updateItem.className = 'update-item';
            updateItem.innerHTML = `
                <span class="version-badge">${version}</span>
                <h3>${release.name || 'Latest Release'}</h3>
                <p>${release.body.substring(0, 300)}${release.body.length > 300 ? '...' : ''}</p>
                <small>Released: ${new Date(release.published_at).toLocaleDateString()}</small>
            `;
            updateList.appendChild(updateItem);
        }
        
    } catch (error) {
        console.error('Error loading release:', error);
        // Show fallback versions
        document.querySelectorAll('.version-tag').forEach(tag => {
            tag.textContent = 'v1.0.0';
        });
    }
}

// Initialize download buttons
function initDownloadButtons() {
    const downloadBtns = document.querySelectorAll('.download-btn');
    
    downloadBtns.forEach(btn => {
        const platform = btn.getAttribute('data-platform');
        const link = downloadLinks[platform];
        
        if (link) {
            btn.href = link;
            btn.target = '_blank';
            btn.rel = 'noopener noreferrer';
        }
        
        btn.addEventListener('click', (e) => {
            if (!link || link === '#') {
                e.preventDefault();
                alert(`${platform.charAt(0).toUpperCase() + platform.slice(1)} download coming soon!`);
            }
        });
    });
}

// Smooth scroll for nav links
function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth' });
            }
        });
    });
}