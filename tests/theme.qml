import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Plugin" as Plugin

ShellRoot {
    id: root
    Plugin.Service { id: service }
    TestCase { id: checks; when: false }
    function check(value, message) { if (!value) throw new Error(message); }
    function verifyTheme() {
        var card = checks.findChild(service.themeTestPanels.instances[0].contentItem, "displayResetCard");
        var heading = checks.findChild(service.themeTestPanels.instances[0].contentItem, "displayResetHeading");
        var monitor = checks.findChild(service.themeTestPanels.instances[0].contentItem, "displayResetMonitor");
        check(card && heading && monitor, "Dialog objects are missing");
        check(card.color === Commons.Color.background, "Card background");
        check(card.border.color === Commons.Color.accent, "Card border");
        check(heading.color === Commons.Color.foreground, "Heading color");
        check(monitor.border.color === Commons.Color.foreground, "Monitor border");
        service.selected = ["test"];
        checks.wait(30);
        check(monitor.border.color === Commons.Color.accent, "Selected monitor accent");
        service.selected = [];
    }
    Timer {
        interval: 250; running: true
        onTriggered: {
            try {
                service.displays = [{name: "test", model: "Test", x: 0, y: 0, width: 1920, height: 1080}];
                checks.wait(30);
                verifyTheme();
                Commons.Color.loadColors('background = "#060b1e"\nforeground = "#ffcead"\naccent = "#7d82d9"');
                checks.wait(30);
                verifyTheme();
                Commons.Color.loadColors('background = "#fafafa"\nforeground = "#202020"\naccent = "#0055aa"');
                checks.wait(30);
                verifyTheme();
                check(!service.busy, "Display reload was unexpectedly started");
                console.log("PLUGIN_THEME_PASS");
            } catch (error) { console.log("PLUGIN_THEME_FAIL", String(error)); }
            Qt.quit();
        }
    }
}
