package;

enum abstract LibUrl(String) from String to String {
    var macDebug = "https://github.com/sunabagg/sunaba/releases/download/nightly/sunaba-macos-latest-Debug.zip";
    var macRelease = "https://github.com/sunabagg/sunaba/releases/download/nightly/sunaba-macos-latest-Release.zip";
    var linuxDebug = "https://github.com/sunabagg/sunaba/releases/download/nightly/sunaba-ubuntu-22.04-Debug.zip";
    var linuxRelease = "https://github.com/sunabagg/sunaba/releases/download/nightly/sunaba-ubuntu-22.04-Release.zip";
    var windowsDebug = "https://github.com/sunabagg/sunaba/releases/download/nightly/sunaba-windows-latest-Debug.zip";
    var windowsRelease = "https://github.com/sunabagg/sunaba/releases/download/nightly/sunaba-windows-latest-Release.zip";
}