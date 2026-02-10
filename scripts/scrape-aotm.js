/**
 * AotM Scraper
 *
 * Scrapes Achievement of the Month data directly from RetroAchievements.org
 * Uses Puppeteer with stealth plugin to handle Cloudflare protection.
 * Then uses the RA API to get full achievement/game details.
 */

const fs = require('fs');
const https = require('https');

// Try to load puppeteer-extra with stealth, fallback to regular puppeteer
let puppeteer;
let StealthPlugin;
try {
  puppeteer = require('puppeteer-extra');
  StealthPlugin = require('puppeteer-extra-plugin-stealth');
  puppeteer.use(StealthPlugin());
  console.log('Using puppeteer-extra with stealth plugin');
} catch (e) {
  puppeteer = require('puppeteer');
  console.log('Using standard puppeteer (stealth plugin not available)');
}

const AOTM_FILE = 'aotm.json';
const EVENT_URL = 'https://retroachievements.org/achievement-of-the-week';
const RA_API_BASE = 'https://retroachievements.org/API';

// Get credentials from environment
const RA_USERNAME = process.env.RA_USERNAME;
const RA_API_KEY = process.env.RA_API_KEY;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode}`));
        return;
      }
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error('Invalid JSON'));
        }
      });
    }).on('error', reject);
  });
}

async function getGameDetails(gameId) {
  if (!RA_USERNAME || !RA_API_KEY) return null;
  const url = `${RA_API_BASE}/API_GetGame.php?z=${RA_USERNAME}&y=${RA_API_KEY}&i=${gameId}`;
  try {
    await sleep(200); // Rate limiting
    return await fetchJson(url);
  } catch (e) {
    console.error(`  Failed to get game ${gameId}:`, e.message);
    return null;
  }
}

async function getGameExtended(gameId) {
  if (!RA_USERNAME || !RA_API_KEY) return null;
  const url = `${RA_API_BASE}/API_GetGameExtended.php?z=${RA_USERNAME}&y=${RA_API_KEY}&i=${gameId}`;
  try {
    await sleep(200); // Rate limiting
    return await fetchJson(url);
  } catch (e) {
    console.error(`  Failed to get extended game ${gameId}:`, e.message);
    return null;
  }
}

async function scrapeEventPage() {
  console.log('Launching browser...');

  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--window-size=1920,1080',
    ],
  });

  try {
    const page = await browser.newPage();

    // Randomize viewport slightly
    const width = 1920 + Math.floor(Math.random() * 100);
    const height = 1080 + Math.floor(Math.random() * 100);
    await page.setViewport({ width, height });

    // Set realistic headers
    await page.setExtraHTTPHeaders({
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    });

    console.log('Navigating to:', EVENT_URL);

    // First visit the main site to get cookies
    await page.goto('https://retroachievements.org', {
      waitUntil: 'networkidle2',
      timeout: 60000
    });
    await sleep(3000);

    // Now navigate to the event page
    await page.goto(EVENT_URL, {
      waitUntil: 'networkidle2',
      timeout: 60000
    });

    // Wait for potential Cloudflare challenge
    await sleep(5000);

    // Check if we're still on Cloudflare
    let content = await page.content();
    let attempts = 0;
    while ((content.includes('Just a moment') || content.includes('Checking your browser')) && attempts < 3) {
      console.log('Cloudflare challenge detected, waiting... (attempt', attempts + 1, ')');
      await sleep(10000);
      content = await page.content();
      attempts++;
    }

    // Try to get the page title to verify we loaded
    const title = await page.title();
    console.log('Page title:', title);

    if (title.includes('Just a moment') || title.includes('Cloudflare')) {
      throw new Error('Could not bypass Cloudflare protection');
    }

    // Extract achievement data from the page
    const scrapedData = await page.evaluate(() => {
      const results = {
        aotw: null,
        aotm: null,
        allAchievements: [],
        allGames: [],
        rawText: '',
        pageStructure: []
      };

      // Get page text for debugging
      results.rawText = document.body?.innerText?.substring(0, 5000) || '';

      // Find ALL achievement and game links on the page
      document.querySelectorAll('a').forEach(link => {
        const href = link.getAttribute('href') || '';
        const text = link.innerText?.trim() || '';

        // Achievement links
        const achMatch = href.match(/\/achievement\/(\d+)/);
        if (achMatch) {
          results.allAchievements.push({
            id: achMatch[1],
            text: text.substring(0, 100),
            href: href
          });
        }

        // Game links
        const gameMatch = href.match(/\/game\/(\d+)/);
        if (gameMatch) {
          results.allGames.push({
            id: gameMatch[1],
            text: text.substring(0, 100),
            href: href
          });
        }
      });

      // Look for specific sections
      const headers = document.querySelectorAll('h1, h2, h3, h4, h5, h6, .card-header, [class*="title"]');
      headers.forEach(header => {
        const text = header.innerText?.toLowerCase() || '';
        results.pageStructure.push({
          tag: header.tagName,
          text: header.innerText?.substring(0, 100)
        });

        // Find the parent container for month section
        if (text.includes('month') || text.includes('aotm')) {
          let container = header.parentElement;
          for (let i = 0; i < 5 && container; i++) {
            const achievements = [];
            const games = [];

            container.querySelectorAll('a').forEach(link => {
              const href = link.getAttribute('href') || '';
              const linkText = link.innerText?.trim() || '';

              const achMatch = href.match(/\/achievement\/(\d+)/);
              if (achMatch) achievements.push({ id: achMatch[1], text: linkText });

              const gameMatch = href.match(/\/game\/(\d+)/);
              if (gameMatch) games.push({ id: gameMatch[1], text: linkText });
            });

            if (achievements.length > 0 || games.length > 0) {
              results.aotm = { achievements, games, headerText: header.innerText };
              break;
            }

            container = container.parentElement;
          }
        }
      });

      // Deduplicate
      const uniqueAch = {};
      results.allAchievements.forEach(a => { uniqueAch[a.id] = a; });
      results.allAchievements = Object.values(uniqueAch);

      const uniqueGame = {};
      results.allGames.forEach(g => { uniqueGame[g.id] = g; });
      results.allGames = Object.values(uniqueGame);

      return results;
    });

    console.log('\n=== Scrape Results ===');
    console.log('Total achievement links found:', scrapedData.allAchievements.length);
    console.log('Total game links found:', scrapedData.allGames.length);
    console.log('AotM section found:', scrapedData.aotm ? 'Yes' : 'No');

    if (scrapedData.aotm) {
      console.log('\nAotM Section:');
      console.log('  Header:', scrapedData.aotm.headerText);
      console.log('  Achievements:', scrapedData.aotm.achievements.length);
      console.log('  Games:', scrapedData.aotm.games.length);

      scrapedData.aotm.achievements.forEach(a => {
        console.log(`    - Achievement ${a.id}: ${a.text}`);
      });
    }

    console.log('\nPage structure:');
    scrapedData.pageStructure.slice(0, 10).forEach(h => {
      console.log(`  ${h.tag}: ${h.text}`);
    });

    // Save screenshot
    try {
      await page.screenshot({ path: '/tmp/ra-event-page.png', fullPage: true });
      console.log('\nScreenshot saved to /tmp/ra-event-page.png');
    } catch (e) {
      console.log('Could not save screenshot:', e.message);
    }

    await browser.close();
    return scrapedData;

  } catch (error) {
    console.error('Scraping error:', error.message);
    try {
      await browser.close();
    } catch (e) {}
    throw error;
  }
}

async function buildAotmEntry(achievementId, gameId, startDate, endDate, swaps = []) {
  console.log(`\nBuilding entry for achievement ${achievementId}, game ${gameId}`);

  const gameDetails = await getGameDetails(gameId);
  const gameExtended = await getGameExtended(gameId);

  if (!gameDetails) {
    console.error('  Could not get game details');
    return null;
  }

  // Find the achievement in the extended data
  let achievement = null;
  if (gameExtended?.Achievements) {
    achievement = Object.values(gameExtended.Achievements).find(
      a => String(a.ID) === String(achievementId)
    );
  }

  if (!achievement) {
    console.error('  Could not find achievement in game data');
    return null;
  }

  console.log(`  Found: ${achievement.Title} - ${gameDetails.Title}`);

  const entry = {
    gameId: parseInt(gameId),
    gameTitle: gameDetails.Title || '',
    gameImageIcon: gameDetails.ImageIcon || '',
    gameImageTitle: gameDetails.ImageTitle || '',
    gameImageIngame: gameDetails.ImageIngame || '',
    gameImageBoxArt: gameDetails.ImageBoxArt || '',
    consoleID: parseInt(gameDetails.ConsoleID) || 0,
    consoleName: gameDetails.ConsoleName || '',
    achievementId: parseInt(achievementId),
    achievementTitle: achievement.Title || '',
    achievementDescription: achievement.Description || '',
    achievementBadgeName: String(achievement.BadgeName || ''),
    achievementDateStart: startDate,
    achievementDateEnd: endDate,
    swaps: []
  };

  // Build swap entries
  for (const swap of swaps) {
    console.log(`  Building swap: achievement ${swap.achievementId}, game ${swap.gameId}`);
    const swapEntry = await buildSwapEntry(swap.achievementId, swap.gameId);
    if (swapEntry) {
      entry.swaps.push(swapEntry);
    }
  }

  return entry;
}

async function buildSwapEntry(achievementId, gameId) {
  const gameDetails = await getGameDetails(gameId);
  const gameExtended = await getGameExtended(gameId);

  if (!gameDetails) return null;

  let achievement = null;
  if (gameExtended?.Achievements) {
    achievement = Object.values(gameExtended.Achievements).find(
      a => String(a.ID) === String(achievementId)
    );
  }

  if (!achievement) return null;

  return {
    gameId: parseInt(gameId),
    gameTitle: gameDetails.Title || '',
    gameImageIcon: gameDetails.ImageIcon || '',
    gameImageTitle: gameDetails.ImageTitle || '',
    gameImageIngame: gameDetails.ImageIngame || '',
    gameImageBoxArt: gameDetails.ImageBoxArt || '',
    consoleID: parseInt(gameDetails.ConsoleID) || 0,
    consoleName: gameDetails.ConsoleName || '',
    achievementId: parseInt(achievementId),
    achievementTitle: achievement.Title || '',
    achievementDescription: achievement.Description || '',
    achievementBadgeName: String(achievement.BadgeName || '')
  };
}

function getCurrentData() {
  try {
    return JSON.parse(fs.readFileSync(AOTM_FILE, 'utf8'));
  } catch (e) {
    return [];
  }
}

function isDataStale(data) {
  if (!Array.isArray(data) || data.length === 0) return true;

  const now = new Date();
  const latest = data[data.length - 1];
  const endDate = new Date(latest?.achievementDateEnd);

  return endDate < now;
}

async function main() {
  console.log('='.repeat(60));
  console.log('RetroAchievements AotM Scraper');
  console.log('Date:', new Date().toISOString());
  console.log('='.repeat(60));

  if (!RA_USERNAME || !RA_API_KEY) {
    console.error('\n*** ERROR: RA_USERNAME and RA_API_KEY required ***');
    console.log('Add these as repository secrets in GitHub:');
    console.log('  Settings -> Secrets and variables -> Actions -> New repository secret');
    console.log('  RA_USERNAME: Your RetroAchievements username');
    console.log('  RA_API_KEY: Your API key from https://retroachievements.org/settings');
    process.exit(1);
  }

  console.log('\nCredentials:');
  console.log('  Username:', RA_USERNAME);
  console.log('  API Key: ****' + RA_API_KEY.slice(-4));

  // Load current data
  const currentData = getCurrentData();
  const isStale = isDataStale(currentData);

  console.log('\nCurrent data:');
  console.log('  Entries:', currentData.length);
  console.log('  Is stale:', isStale);

  if (currentData.length > 0) {
    const latest = currentData[currentData.length - 1];
    console.log('  Latest:', latest.achievementTitle, '-', latest.gameTitle);
    console.log('  Ends:', latest.achievementDateEnd);
  }

  try {
    // Scrape the event page
    const scrapedData = await scrapeEventPage();

    // Check if we got useful data
    if (scrapedData.aotm && scrapedData.aotm.achievements.length > 0) {
      console.log('\n*** Found AotM data! ***');

      // TODO: Implement full data extraction
      // For now, we'll need to manually set dates since they're not easily scraped
      // The achievement/game IDs are extracted and can be used with the RA API

      // Example: Build entries from scraped IDs
      // This would need to be enhanced to also scrape the dates from the page

    } else if (scrapedData.allAchievements.length > 0) {
      console.log('\n*** Found achievement data but could not identify AotM section ***');
      console.log('All achievements found:');
      scrapedData.allAchievements.slice(0, 10).forEach(a => {
        console.log(`  ${a.id}: ${a.text}`);
      });
    } else {
      console.log('\n*** No achievement data found ***');
      console.log('Page may be behind Cloudflare or structure changed.');
      console.log('\nPage text preview:');
      console.log(scrapedData.rawText.substring(0, 500));
    }

    if (isStale) {
      console.log('\n*** WARNING: Current data is stale! ***');
      console.log('Manual update may be required.');
      // In a real implementation, we could create a GitHub issue here
    }

    console.log('\n' + '='.repeat(60));
    console.log('Scrape complete');
    console.log('='.repeat(60));

  } catch (error) {
    console.error('\n*** Scraping failed ***');
    console.error('Error:', error.message);

    if (isStale) {
      console.error('\n*** CRITICAL: Data is stale and scraping failed! ***');
      process.exit(1);
    }

    console.log('\nCurrent data is still valid, no action needed.');
  }
}

main();
