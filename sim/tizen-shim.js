// TV simulator, part 1: stands in for the Tizen platform so the real tizen.js and the
// web client's Tizen code paths run in a desktop browser (scripts/web-dev.sh --tv).
// Runs before tizen.js and the web client. Not part of the app.
(function () {
    'use strict';

    // Samsung TV user agents by Tizen version (the web client reads the version from it)
    var chromium = { '5.5': '69.0.3497.106', '6.0': '76.0.3809.146', '6.5': '85.0.4183.93', '7.0': '94.0.4606.31', '8.0': '108.0.5359.1' };
    var tizenVersion = window.__TV_SIM_TIZEN_VERSION || '6.5';
    var userAgent = 'Mozilla/5.0 (SMART-TV; LINUX; Tizen ' + tizenVersion + ') AppleWebKit/537.36 (KHTML, like Gecko) '
        + (chromium[tizenVersion] || chromium['6.5']) + '/' + tizenVersion + ' TV Safari/537.36';
    Object.defineProperty(navigator, 'userAgent', { get: function () { return userAgent; } });
    Object.defineProperty(navigator, 'appVersion', { get: function () { return userAgent.slice(8); } });

    // Set by the build for the real app (gulpfile.babel.js)
    window.appMode = 'cordova';

    var registeredKeys = {};

    window.tizen = {
        application: {
            getCurrentApplication: function () {
                return {
                    appInfo: { version: '0.0.0-sim' },
                    exit: function () {
                        document.documentElement.innerHTML = '<body style="background:#000;color:#ccc;font:24px sans-serif;display:flex;'
                            + 'align-items:center;justify-content:center;height:100vh;margin:0">App exited. Reload to start it again.</body>';
                    }
                };
            }
        },
        systeminfo: {
            getPropertyValue: function (property, onSuccess) {
                setTimeout(function () {
                    onSuccess({ resolutionWidth: 1920, resolutionHeight: 1080 });
                });
            }
        },
        tvinputdevice: {
            registerKey: function (name) { registeredKeys[name] = true; },
            unregisterKey: function (name) { delete registeredKeys[name]; }
        }
    };

    window.webapis = {
        productinfo: {
            isUdPanelSupported: function () { return false; },
            is8KPanelSupported: function () { return false; }
        }
    };

    // For remote.js: the TV only delivers media keys the app has registered
    window.__tvSim = { registeredKeys: registeredKeys, tizenVersion: tizenVersion };
}());
