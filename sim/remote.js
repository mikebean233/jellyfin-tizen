// TV simulator, part 2: makes the keyboard behave like a Samsung remote and takes away
// the mouse, which a remote doesn't have (scripts/web-dev.sh --tv). Not part of the app.
//
// Arrows and Enter are the D-pad and OK as they are. Other keys are mapped to remote
// buttons below and sent with the key codes a Samsung TV uses; keys a remote doesn't
// have are dropped, so nothing works here that wouldn't on the TV. In a text field
// with the on-screen keyboard open (OK on the field opens it, Back closes it) the
// keyboard types, standing in for the TV's.
(function () {
    'use strict';

    var BACK = { name: 'Back', key: 'XF86Back', keyCode: 10009 };
    // Media buttons reach the app only while tizen.js has registered them, as on the TV
    var MEDIA = {
        p: { name: 'Play/Pause', key: 'MediaPlayPause', keyCode: 10252, register: 'MediaPlayPause' },
        y: { name: 'Play', key: 'MediaPlay', keyCode: 415, register: 'MediaPlay' },
        // As a Samsung TV sends it (jellyfin-tizen#314)
        u: { name: 'Pause', key: 'XF86AudioPause', keyCode: 19, code: 'MediaPause', register: 'MediaPause' },
        s: { name: 'Stop', key: 'MediaStop', keyCode: 413, register: 'MediaStop' },
        ',': { name: 'Rewind', key: 'MediaRewind', keyCode: 412, register: 'MediaRewind' },
        '.': { name: 'Fast-forward', key: 'MediaFastForward', keyCode: 417, register: 'MediaFastForward' },
        '[': { name: 'Previous', key: 'MediaTrackPrevious', keyCode: 10232, register: 'MediaTrackPrevious' },
        ']': { name: 'Next', key: 'MediaTrackNext', keyCode: 10233, register: 'MediaTrackNext' }
    };
    var NATIVE = { ArrowUp: 'Up', ArrowDown: 'Down', ArrowLeft: 'Left', ArrowRight: 'Right', Enter: 'OK' };

    var mouseBlocked = true;
    var legend;
    var lastKey;

    // A field the web client holds read-only has the TV's keyboard closed (OK opens it)
    function isEditable(el) {
        if (!el || el.readOnly) return false;
        if (el.isContentEditable) return true;
        if (el.tagName === 'TEXTAREA') return true;
        return el.tagName === 'INPUT' && !/^(button|checkbox|color|file|hidden|image|radio|range|reset|submit)$/i.test(el.type);
    }

    function send(button) {
        var target = document.activeElement || document.body;
        ['keydown', 'keyup'].forEach(function (type) {
            var event = new KeyboardEvent(type, { key: button.key, code: button.code || '', bubbles: true, cancelable: true });
            Object.defineProperty(event, 'keyCode', { get: function () { return button.keyCode; } });
            Object.defineProperty(event, 'which', { get: function () { return button.keyCode; } });
            target.dispatchEvent(event);
        });
    }

    function show(text) {
        lastKey = text;
        render();
    }

    window.addEventListener('keydown', function (e) {
        if (!e.isTrusted || e.ctrlKey || e.metaKey || e.altKey) return;

        var key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
        var swallow = function () { e.preventDefault(); e.stopImmediatePropagation(); };

        if (NATIVE[key]) {
            show(NATIVE[key]);
            return;
        }
        if (key === 'Escape' || (key === 'Backspace' && !isEditable(document.activeElement))) {
            swallow();
            show('Back');
            send(BACK);
            return;
        }
        if (isEditable(document.activeElement)) {
            return; // typing, as on the TV's on-screen keyboard
        }
        if (key === 'h') {
            swallow();
            legend.hidden = !legend.hidden;
            return;
        }
        if (key === 'm') {
            swallow();
            mouseBlocked = !mouseBlocked;
            document.documentElement.classList.toggle('tvsim-nomouse', mouseBlocked);
            show(mouseBlocked ? 'Mouse off' : 'Mouse on');
            return;
        }
        if (MEDIA[key]) {
            swallow();
            var button = MEDIA[key];
            if (window.__tvSim.registeredKeys[button.register]) {
                show(button.name);
                send(button);
            } else {
                show(button.name + ' (not registered here, the TV keeps it)');
            }
            return;
        }
        if (key.length === 1 || key === 'Tab') {
            swallow(); // no such button on a remote
            show('"' + e.key + '" (not on a remote)');
        }
    }, true);

    // No pointer: a remote can't click, hover or scroll
    ['mousedown', 'mouseup', 'click', 'dblclick', 'contextmenu', 'mousemove', 'mouseover', 'mouseout',
        'pointerdown', 'pointerup', 'pointermove', 'wheel', 'touchstart'].forEach(function (type) {
        window.addEventListener(type, function (e) {
            // OK (Enter) on a button or form fires a real click too, with detail 0: keep those
            var fromKeyboard = (type === 'click' || type === 'pointerdown' || type === 'pointerup') && e.detail === 0;
            if (mouseBlocked && e.isTrusted && !fromKeyboard) {
                e.preventDefault();
                e.stopImmediatePropagation();
            }
        }, { capture: true, passive: false });
    });

    function render() {
        if (!legend) return;
        var size = window.innerWidth + '×' + window.innerHeight;
        var sizeNote = size === '1920×1080' ? size : size + ' (the TV is 1920×1080: use the device toolbar)';
        legend.innerHTML = '<b>TV simulator</b> · Tizen ' + window.__tvSim.tizenVersion + ' · ' + sizeNote
            + '<br>Arrows: D-pad · Enter: OK · Esc / Backspace: Back'
            + '<br>Text field: OK opens the keyboard (type on yours), Back closes it'
            + '<br>P play/pause · Y play · U pause · S stop · , rewind · . fast-forward · [ previous · ] next'
            + '<br>H hide this · M mouse ' + (mouseBlocked ? 'off' : 'on')
            + (lastKey ? '<br>Last: <b>' + lastKey.replace(/</g, '&lt;') + '</b>' : '');
    }

    function init() {
        var style = document.createElement('style');
        style.textContent = '.tvsim-nomouse, .tvsim-nomouse * { cursor: none !important; }'
            + '#tvsim-legend { position: fixed; left: 8px; bottom: 8px; z-index: 2147483647; pointer-events: none;'
            + ' background: rgba(0,0,0,.75); color: #ddd; font: 12px/1.5 sans-serif; padding: 6px 10px; border-radius: 6px; }'
            + '#tvsim-legend b { color: #fff; }';
        document.head.appendChild(style);
        document.documentElement.classList.add('tvsim-nomouse');

        legend = document.createElement('div');
        legend.id = 'tvsim-legend';
        document.body.appendChild(legend);
        render();
        window.addEventListener('resize', render);
    }

    if (document.body) {
        init();
    } else {
        document.addEventListener('DOMContentLoaded', init);
    }
}());
