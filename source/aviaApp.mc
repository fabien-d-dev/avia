import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class aviaApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new aviaView() ];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

function getApp() as aviaApp {
    return Application.getApp() as aviaApp;
}