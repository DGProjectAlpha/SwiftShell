# Finish animated popout dismissal and release backdrop blur

Date: 2026-11-08

Enabling animated popout close exposed an existing lifecycle error:
PopoverHost used NumberAnimation.onFinished inside a Behavior to dispatch the
state machine’s animationFinished action. Qt does not emit that signal for
animations owned by a Behavior. The surface could become transparent while its
native layer remained mapped and its backdrop blur remained requested. A second
close saw zero opacity and forced an immediate close, explaining the extra click.

Observe the surface’s actual opacity reaching the state machine’s requested
endpoint instead. Defer the completion action to the next event turn so state
updates and animation reversal settle first. Existing phase/opacity checks reject
stale completion actions. Also stop requesting blur when the painted opacity
reaches zero, independently of window lifetime. Fade/slide durations and immediate
input/focus release remain unchanged. Menu diagnostics now report phase, opacity,
grab and interactivity for regression evidence.

The native regression opens the existing top bar’s context popout with a real
right-click and dismisses it with exactly one click on the empty bar inset,
outside the popout. It checks visible=false, blur=false and a closed lifecycle,
then restores cursor and focus. Clicking a desktop gap is not equivalent: it may
leave keyboard focus and the focus grab unchanged, so the test deliberately uses
the real bar dismissal handler without clicking application content.

The HDMI-A-1 run passed with openedWithBlur=true and, after one outside click,
visible=false, blur=false, phase=closed, opacity=0, grab=false, interactive=false.
The owner explicitly authorized this narrowly scoped existing-bar click test
while a fullscreen application was active. No fixture window was launched. The
reusable tests/live/popover-close.py CLI retains the normal fullscreen preflight;
no general fullscreen bypass or compositor setting was added.

The shared PopoverHost serves both outputs; the requested live check ran on
HDMI-A-1. Other popout contents and physical GPU combinations remain manual
checks. Reverting this source commit restores the previous behavior; no user
preferences, Noctalia, keyboard bindings or monitor configuration were changed.

API evidence: [Qt Animation.finished](https://doc.qt.io/qt-6/qml-qtquick-animation.html#finished-signal).
