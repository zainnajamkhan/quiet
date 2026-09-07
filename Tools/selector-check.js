// Quiet selector check, generated from ruleset v5.
// Paste into Safari's Web Inspector console (Develop > Show Web Inspector > Console)
// while on the site you want to check, then read the table.
(function () {
  var RULESET = {
  "schemaVersion": 1,
  "rulesetVersion": 5,
  "updatedAt": "2026-09-07",
  "sites": [
    {
      "id": "youtube",
      "name": "YouTube",
      "matches": [
        "*://*.youtube.com/*"
      ],
      "features": [
        {
          "id": "youtube.home-feed",
          "name": "Home page recommendation grid",
          "summary": "The wall of recommended videos on the home page. Search and subscriptions still work.",
          "defaultEnabled": true,
          "appliesTo": [
            "/",
            "/?*"
          ],
          "hide": [
            "ytd-rich-grid-renderer"
          ],
          "verify": [
            "ytd-app"
          ]
        },
        {
          "id": "youtube.shorts",
          "name": "Shorts shelves",
          "summary": "Shorts shelves and Shorts thumbnails, wherever they turn up.",
          "defaultEnabled": true,
          "hide": [
            "grid-shelf-view-model",
            "ytm-shorts-lockup-view-model"
          ],
          "verify": [
            "ytd-app"
          ]
        },
        {
          "id": "youtube.up-next",
          "name": "Up next sidebar",
          "summary": "The recommended videos column beside whatever you are watching.",
          "defaultEnabled": false,
          "hide": [
            "ytd-watch-next-secondary-results-renderer"
          ],
          "verify": [
            "ytd-app"
          ]
        },
        {
          "id": "youtube.comments",
          "name": "Comments",
          "defaultEnabled": false,
          "hide": [
            "#comments"
          ],
          "verify": [
            "ytd-app"
          ],
          "summary": "The comment section under a video."
        }
      ]
    },
    {
      "id": "x",
      "name": "X (Twitter)",
      "matches": [
        "*://*.x.com/*",
        "*://*.twitter.com/*"
      ],
      "features": [
        {
          "id": "x.sidebar",
          "name": "Trends and Who to follow sidebar",
          "summary": "The right hand column: trending topics and who to follow.",
          "defaultEnabled": true,
          "hide": [
            "[data-testid=\"sidebarColumn\"]"
          ],
          "verify": [
            "[data-testid=\"primaryColumn\"]"
          ]
        },
        {
          "id": "x.explore",
          "name": "Explore page contents",
          "summary": "Empties the Explore tab, so opening it is a dead end.",
          "defaultEnabled": false,
          "appliesTo": [
            "/explore*"
          ],
          "hide": [
            "[data-testid=\"primaryColumn\"] section"
          ],
          "verify": [
            "[data-testid=\"primaryColumn\"]"
          ]
        }
      ]
    },
    {
      "id": "linkedin",
      "name": "LinkedIn",
      "matches": [
        "*://*.linkedin.com/*"
      ],
      "features": [
        {
          "id": "linkedin.feed",
          "name": "Home feed",
          "summary": "The scrolling post feed. Messaging, jobs and profiles stay usable.",
          "defaultEnabled": true,
          "appliesTo": [
            "/feed*",
            "/",
            "/?*"
          ],
          "hide": [
            ".scaffold-finite-scroll",
            ".scaffold-finite-scroll__content"
          ],
          "verify": [
            "main"
          ]
        },
        {
          "id": "linkedin.news",
          "name": "LinkedIn News and suggestions rail",
          "summary": "The right hand column with LinkedIn News and feed suggestions.",
          "defaultEnabled": true,
          "hide": [
            "aside.scaffold-layout__aside"
          ],
          "verify": [
            "main"
          ]
        }
      ]
    },
    {
      "id": "reddit",
      "name": "Reddit",
      "matches": [
        "*://*.reddit.com/*"
      ],
      "features": [
        {
          "id": "reddit.home-feed",
          "name": "Home feed",
          "summary": "The front page post list. Individual subreddits stay browsable.",
          "defaultEnabled": true,
          "appliesTo": [
            "/",
            "/?*"
          ],
          "hide": [
            "shreddit-feed",
            "main shreddit-post"
          ],
          "verify": [
            "shreddit-app"
          ]
        },
        {
          "id": "reddit.related-posts",
          "name": "Related posts under a thread",
          "defaultEnabled": false,
          "hide": [
            "shreddit-comments-page-ad",
            "[data-testid=\"related-posts\"]"
          ],
          "verify": [
            "shreddit-app"
          ],
          "summary": "The related posts pulled in under a thread."
        }
      ]
    },
    {
      "id": "instagram",
      "name": "Instagram",
      "matches": [
        "*://*.instagram.com/*"
      ],
      "features": [
        {
          "id": "instagram.reels-nav",
          "name": "Reels navigation link",
          "summary": "The Reels link in the navigation sidebar.",
          "defaultEnabled": true,
          "hide": [
            "a[href=\"/reels/\"]"
          ],
          "verify": [
            "nav"
          ]
        },
        {
          "id": "instagram.explore-nav",
          "name": "Explore navigation link",
          "defaultEnabled": true,
          "hide": [
            "a[href=\"/explore/\"]"
          ],
          "verify": [
            "nav"
          ],
          "summary": "The Explore link in the navigation sidebar."
        }
      ]
    },
    {
      "id": "facebook",
      "name": "Facebook",
      "matches": [
        "*://*.facebook.com/*"
      ],
      "features": [
        {
          "id": "facebook.feed",
          "name": "News feed",
          "summary": "The main scrolling news feed on the home page.",
          "defaultEnabled": true,
          "appliesTo": [
            "/",
            "/?*"
          ],
          "hide": [
            "[role=\"feed\"]"
          ],
          "verify": [
            "[role=\"banner\"]"
          ]
        },
        {
          "id": "facebook.reels-nav",
          "name": "Reels and Marketplace links",
          "defaultEnabled": false,
          "hide": [
            "a[href^=\"/reel\"]",
            "a[href^=\"/marketplace\"]"
          ],
          "verify": [
            "[role=\"banner\"]"
          ],
          "summary": "The Reels and Marketplace links in the navigation."
        }
      ]
    }
  ]
};

  function globToRegExp(glob) {
    return new RegExp("^" + String(glob).replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*") + "$");
  }

  function hostMatches(patternHost, host) {
    if (patternHost === "*") return true;
    if (patternHost.indexOf("*.") === 0) {
      var suffix = patternHost.slice(2);
      return host === suffix || host.slice(-(suffix.length + 1)) === "." + suffix;
    }
    return host === patternHost;
  }

  function siteForHost(host) {
    for (var i = 0; i < RULESET.sites.length; i++) {
      var site = RULESET.sites[i];
      for (var j = 0; j < site.matches.length; j++) {
        var m = /^(\*|https?):\/\/([^/]+)(\/.*)$/.exec(site.matches[j]);
        if (m && hostMatches(m[2].toLowerCase(), host)) return site;
      }
    }
    return null;
  }

  function count(selector) {
    try {
      return document.querySelectorAll(selector).length;
    } catch (e) {
      return "INVALID SELECTOR";
    }
  }

  var host = location.hostname.toLowerCase();
  var site = siteForHost(host);
  if (!site) {
    console.log("%cQuiet: no rules defined for " + host, "color:orange;font-weight:bold");
    return;
  }

  var pathAndQuery = location.pathname + location.search;
  console.log("%cQuiet selector check -- " + site.name + " -- " + pathAndQuery, "font-weight:bold;font-size:14px");

  var rows = [];
  site.features.forEach(function (feature) {
    var applies = true;
    if (feature.appliesTo && feature.appliesTo.length) {
      applies = feature.appliesTo.some(function (g) { return globToRegExp(g).test(pathAndQuery); });
    }

    var pageRecognised = true;
    if (feature.verify && feature.verify.length) {
      pageRecognised = feature.verify.some(function (s) { return count(s) > 0; });
    }

    feature.hide.forEach(function (selector) {
      var n = count(selector);
      var status;
      if (!applies) status = "n/a on this page";
      else if (!pageRecognised) status = "PAGE NOT RECOGNISED (verify selector missing)";
      else if (n === "INVALID SELECTOR") status = "INVALID SELECTOR";
      else if (n === 0) status = "*** BROKEN: matches nothing ***";
      else status = "ok (" + n + ")";

      rows.push({ feature: feature.id, selector: selector, matches: n, status: status });
    });
  });

  if (console.table) console.table(rows);
  else rows.forEach(function (r) { console.log(r.feature, r.selector, r.status); });

  var broken = rows.filter(function (r) { return r.status.indexOf("BROKEN") >= 0 || r.status.indexOf("INVALID") >= 0; });
  if (broken.length === 0) {
    console.log("%cAll applicable selectors matched something.", "color:green;font-weight:bold");
  } else {
    console.log("%c" + broken.length + " selector(s) need fixing:", "color:red;font-weight:bold");
    broken.forEach(function (r) { console.log("  " + r.feature + "  ->  " + r.selector); });
  }
})();
