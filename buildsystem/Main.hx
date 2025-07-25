package;

import sys.FileSystem;
import sys.io.File;
import js.node.Http;
import js.node.Https;
import js.node.Url;
import js.node.buffer.Buffer;
import haxe.http.HttpNodeJs;
import haxe.io.Bytes;
import haxe.zip.Reader;
import haxe.io.BytesInput;

class Main {
    static var godotCommand = "godot";

    static var targetPlatform = "";

    static var exportType = ExportType.debug;

    static var packageFormat = PackageFormat.none;

    static var targetName: String = "";

    public static function main() {
        var args = Sys.args();

        if (args[0] == "-h" || args[0] == "--help") {
            Sys.println("Usage: node build [run|export] [--godot-command=<command>] [--target=<platform>] [-debug|-release]");
            Sys.println("  run: Run sunabacmd");
            Sys.println("  --godot-command=<command>: Specify the Godot command to use (default: godot)");
            Sys.println("  --skip: Skip the build step");
            Sys.println("  export: Export sunabacmd for the specified platform");
            Sys.println("  --skip -s: Skip the build step");
            Sys.println("  --godot-command=<command>: Specify the Godot command to use (default: godot)");
            Sys.println("  --target=<platform> -t=<platform>: Specify the target platform (default: auto-detect based on OS)");
            Sys.println("  --debug -d: Export in debug mode");
            Sys.println("  --release -r: Export in release mode");
            Sys.println("  --pkgformat=<format> -p: Specify the package format (none, nsis, deb, dmg)");
            return;
        }

        if (args[0] == "install") {
            if (Sys.systemName() == "Linux") {
                exportType = ExportType.release;
                var usrPath = "/usr/";
                setupBin();
                buildUnixUsrDir(usrPath);
                return;
            }
        }

        if (args[0] == "update") {
            var platform = "windows";
            if (Sys.systemName() == "Mac") {
                platform = "macOS";
            }
            else if (Sys.systemName() == "Linux") {
                platform = "linux";
            }
            var arg1 = args[1];
            if (arg1 != null) {
                if (StringTools.startsWith(arg1, "--platform=")) {
                    platform = StringTools.replace(args[1], "--platform=", "");
                }
            }

            updateLibraries(platform);
            return;
        }

        var currentDir = Sys.getCwd();
        if (StringTools.contains(currentDir, "\\"))
            currentDir = StringTools.replace(currentDir, "\\", "/");

        var skipBuild = false;

        for (i in 0...args.length) {
            var arg = args[i];
            if (StringTools.startsWith(arg, "--godot-command=")) {
                godotCommand = StringTools.replace(arg, "--godot-command=", "");
                Sys.println("Using godot command: " + godotCommand);
            }
            else if (StringTools.startsWith(arg, "--target=")) {
                targetPlatform = StringTools.replace(arg, "--target=", "");
            }
            else if (arg == "--debug" || arg == "-d") {
                exportType = ExportType.debug;
            }
            else if (arg == "--release" || arg == "-r") {
                exportType = ExportType.release;
            }
            else if (arg == "--skip" || arg == "-s") {
                skipBuild = true;
            }
            else if (StringTools.startsWith(arg, "--pkgformat=")) {
                var format = StringTools.replace(arg, "--pkgformat=", "");
                if (format != "") {
                    if (format == "nsis") {
                        packageFormat = PackageFormat.nsis;
                    }
                    else if (format == "deb" || format == "debian") {
                        packageFormat = PackageFormat.deb;
                    }
                    else if (format == "dmg") {
                        packageFormat = PackageFormat.dmg;
                    }
                    else if (format == "zip") {
                        packageFormat = PackageFormat.zip;
                    }
                    else {
                        Sys.println("Unknown package format: " + format);
                        Sys.exit(-1);
                    }
                }
            }
            else if (StringTools.startsWith(arg, "-t=")) {
                targetPlatform = StringTools.replace(arg, "-t=", "");
            }
            else if (StringTools.startsWith(arg, "-p=")) {
                var format = StringTools.replace(arg, "-p=", "");
                if (format != "") {
                    if (format == "nsis") {
                        packageFormat = PackageFormat.nsis;
                    }
                    else if (format == "deb" || format == "debian") {
                        packageFormat = PackageFormat.deb;
                    }
                    else if (format == "dmg") {
                        packageFormat = PackageFormat.dmg;
                    }
                    else if (format == "zip") {
                        packageFormat = PackageFormat.zip;
                    }
                    else {
                        Sys.println("Unknown package format: " + format);
                        Sys.exit(-1);
                    }
                }
            }
        }

        var tsukuru = new Tsukuru();
        tsukuru.zipOutputPath = currentDir + "template/sunabacmd.sbx";
        if (!skipBuild) {
            tsukuru.build(currentDir + "cmd.snbproj");
        }
        else {
            Sys.println("Skipping build step.");
        }


        if (args[0] == "run") {
            run();
            return;
        }
        else if (args[0] == "export") {
            export();
        }

        if (packageFormat == PackageFormat.nsis) {
            buildNsisInstaller();
        }
        else if (packageFormat == PackageFormat.deb) {
            createDebPackage();
        }
        else if (packageFormat == PackageFormat.dmg) {
            exportDmg();
        }
        else if (packageFormat == PackageFormat.zip) {
            exportZip();
        }
    }

    public static function run() {
        var result = Sys.command(godotCommand + " --headless --path ./template");
        Sys.exit(result);
    }

    public static function setupBin() {
        if (targetPlatform == "") {
            var systemName =  Sys.systemName();
            if (systemName == "Windows") {
                targetPlatform = "windows-amd64";
            }
            else if (systemName == "Mac") {
                targetPlatform = "mac-universal";
            }
            else if (systemName == "Linux") {
                targetPlatform = "linux-amd64";
            }
        }
        if (targetPlatform == "mac-universal") {
            targetName = "sunabacmd.app";
        }
        else if (targetPlatform == "windows-amd64") {
            targetName = "sunabacmd.exe";
        }
        else if (targetPlatform == "linux-amd64") {
            targetName = "sunabacmd";
        }
        else {
            Sys.println("Invalid target: " + targetPlatform);
            Sys.exit(-1);
        }

        var rootPath = Sys.getCwd() + "bin";
        if (!FileSystem.exists(rootPath)) {
            FileSystem.createDirectory(rootPath);
        }

        var targetPath = rootPath + "/" + targetPlatform + "-" + exportType;
        if (!FileSystem.exists(targetPath)) {
            FileSystem.createDirectory(targetPath);
        }
    }

    public static function export() {
        setupBin();

        Sys.println("Exporting for target platform: " + targetPlatform);
        Sys.println("Exporting for " + exportType);

        var command = godotCommand + " --path ./template --headless --editor --export-" + exportType + " \"" + targetPlatform + "\" \"../bin/" + targetPlatform + "-" + exportType + "/" + targetName + "\"";
        //trace(command);

        var result = Sys.command(command);
        if (result != 0) {
            trace("Godot export failed with code " + result);
            Sys.println(godotCommand + " exited with code " + result);
            Sys.exit(result);
        }
    }

    public static function buildNsisInstaller() {
        var nsisCommand = "makensis";
        if (Sys.systemName() == "Windows") {
            if (Sys.command(nsisCommand + " /VERSION") != 0) {
                Sys.println("NSIS is not installed or not found in PATH.");
                Sys.exit(-1);
            }
        }
        else if (Sys.systemName() == "Linux" || Sys.systemName() == "Mac") {
            nsisCommand = "makensis";
            if (Sys.command(nsisCommand + " -VERSION") != 0) {
                Sys.println("NSIS is not installed or not found in PATH.");
                Sys.exit(-1);
            }
        }

        var outputInstallerPath = Sys.getCwd() + "bin/" + targetPlatform + "-" + exportType + "-nsis/sunabacmdInstaller.exe";

        if (!FileSystem.exists(Sys.getCwd() + "/bin/" + targetPlatform + "-" + exportType + "-nsis")) {
            FileSystem.createDirectory(Sys.getCwd() + "/bin/" + targetPlatform + "-" + exportType + "-nsis");
        }

        var nsisScript = "setup.nsi";
        if (exportType == ExportType.debug) {
            nsisScript = "setup-debug.nsi";
        }

        var command = nsisCommand + " " + nsisScript;
        trace("Running NSIS command: " + command);
        var result = Sys.command(command);
        if (result != 0) {
            Sys.println("NSIS installer creation failed with code " + result);
            Sys.exit(result);
        }

        Sys.println("NSIS installer created at: " + outputInstallerPath);
    }

    public static function createDebPackage() {
        var cwd = Sys.getCwd();

        if (!StringTools.endsWith(cwd, "/")) {
            cwd += "/";
        }

        var debRootPath = cwd + ".debian/";
        if (!FileSystem.exists(debRootPath)) {
            FileSystem.createDirectory(debRootPath);
        }

        var debPackagePath = debRootPath + "sunabacmd-" + exportType + "/";
        if (!FileSystem.exists(debPackagePath)) {
            FileSystem.createDirectory(debPackagePath);
        }

        var debUsrPath = debPackagePath + "usr/";
        if (!FileSystem.exists(debUsrPath)) {
            FileSystem.createDirectory(debUsrPath);
        }

        buildUnixUsrDir(debUsrPath);

        var debDebianPath = debPackagePath + "DEBIAN/";
        if (!FileSystem.exists(debDebianPath)) {
            FileSystem.createDirectory(debDebianPath);
        }

        var cwdDebianFilesPath = cwd + "debian_files/";

        File.copy(cwdDebianFilesPath + "control", debDebianPath + "control");
        //File.copy(cwdDebianFilesPath + "postinst", debDebianPath + "postinst");
        //File.copy(cwdDebianFilesPath + "preinst", debDebianPath + "preinst");
        //File.copy(cwdDebianFilesPath + "changelog", debDebianPath + "changelog");
        File.copy(cwd + "LICENSE", debDebianPath + "copyright");

        var result = Sys.command("dpkg-deb --build " + debPackagePath);

        if (result != 0) {
            Sys.println("dpkg-deb failed at " + result);
        }

        var debOutputPath = cwd + "bin/" + targetPlatform + "-" + exportType + "-deb/";
        if (!FileSystem.exists(debOutputPath)) {
            FileSystem.createDirectory(debOutputPath);
        }

        var debPackageName = "sunabacmd-" + exportType + ".deb";

        File.copy(debRootPath + debPackageName, debOutputPath + debPackageName);
    }

    public static function buildUnixUsrDir(path: String) {
        var cwd = Sys.getCwd();
        if (!StringTools.endsWith(cwd, "/")) {
            cwd += "/";
        }
        var rootPath = cwd + "bin";
        var exportPath = rootPath + "/" + targetPlatform + "-" + exportType + "/";

        if (!StringTools.endsWith(path, "/")) {
            path += "/";
        }

        var binPath = path + "bin/";
        var libPath = path + "lib/";
        var sharePath = path + "share/";
        var shareSunabaPath = sharePath + "sunaba/";
        var shareApplicationsPath = sharePath + "applications/";
        var sharePixmapsPath = sharePath + "pixmaps/";

        if (!FileSystem.exists(binPath)) {
            FileSystem.createDirectory(binPath);
        }
        if (!FileSystem.exists(libPath)) {
            FileSystem.createDirectory(libPath);
        }
        if (!FileSystem.exists(sharePath)) {
            FileSystem.createDirectory(sharePath);
        }
        if (!FileSystem.exists(shareSunabaPath)) {
            FileSystem.createDirectory(shareSunabaPath);
        }
        if (!FileSystem.exists(shareApplicationsPath)) {
            FileSystem.createDirectory(shareApplicationsPath);
        }
        if (!FileSystem.exists(sharePixmapsPath)) {
            FileSystem.createDirectory(sharePixmapsPath);
        }

        var executableName = "sunabacmd";
        File.copy(exportPath + executableName, binPath + executableName);

        var libraryName = "libsunaba.so";
        if (exportType == ExportType.debug) {
            libraryName = "libsunaba-d.so";
        }
        File.copy(exportPath + libraryName, libPath + libraryName);

        File.copy(exportPath + "sunabacmd", shareSunabaPath + "sunabacmd");
        File.copy(exportPath + "mobdebug.lua", shareSunabaPath + "mobdebug.lua");
        File.copy(cwd + "sunabacmd.desktop", shareApplicationsPath + "sunabacmd.desktop");
        File.copy(cwd + "sunaba.png", sharePixmapsPath + "sunaba.png");
    }

    public static function exportDmg() {
        var applicationsFolder = "/Applications/";
        Sys.command("ln -s /Applications/ " + Sys.getCwd() + "/bin/" + targetPlatform + "-" + exportType + "/Applications");
        Sys.command("hdiutil create -volname 'sunabacmd' -srcfolder 'bin/" + targetPlatform + "-" + exportType + "' -ov -format UDZO 'bin/sunabacmd-" + exportType + ".dmg'");
        Sys.println("DMG package created at: bin/sunabacmd-" + exportType + ".dmg");
        var dmgPath = Sys.getCwd() + "bin/sunabacmd-" + exportType + ".dmg";
        if (!FileSystem.exists(dmgPath)) {
            Sys.println("DMG package creation failed.");
            Sys.exit(-1);
        } else {
            Sys.println("DMG package created successfully at: " + dmgPath);
        }
    }

    public static function exportZip() {
        var zipPath = Sys.getCwd() + "bin/" + targetPlatform + "-" + exportType + ".zip";
        var binPath = Sys.getCwd() + "bin/" + targetPlatform + "-" + exportType + "/";
        if (!FileSystem.exists(binPath)) {
            Sys.println("Export directory does not exist: " + binPath);
            Sys.exit(-1);
        }
        var output = new haxe.io.BytesOutput();
        var zipWriter = new haxe.zip.Writer(output);
        var entries:haxe.ds.List<haxe.zip.Entry> = new haxe.ds.List();
        for (file in FileSystem.readDirectory(binPath)) {
            if (FileSystem.isDirectory(file)) {
                continue; // Skip directories
            }
            var relativePath = StringTools.replace(file, binPath, "");
            var fileBytes = File.getBytes(binPath + file);
            if (fileBytes == null) {
                Sys.println("Failed to read file: " + file);
                continue;
            }
            var entry:haxe.zip.Entry = {
                fileName: relativePath,
                fileSize: fileBytes.length,
                fileTime: Date.now(),
                dataSize: fileBytes.length,
                data: fileBytes,
                crc32: null,
                compressed: false,
                extraFields: null
            };
            entries.push(entry);
        }
        zipWriter.write(entries);
        var zipBytes = output.getBytes();
        File.saveBytes(zipPath, zipBytes);
    }

    public static function downloadWithCustomHttp(url: String, onSuccess: Bytes -> Void, onError: String -> Void): Void {
        //trace("Custom HTTP download from: " + url);
        
        var parsedUrl = new js.node.url.URL(url);
        var secure = parsedUrl.protocol == "https:";
        
        var options = {
            hostname: parsedUrl.hostname,
            port: parsedUrl.port != null ? Std.parseInt(parsedUrl.port) : (secure ? 443 : 80),
            path: parsedUrl.pathname + (parsedUrl.search != null ? parsedUrl.search : ""),
            method: "GET"
        };
        
        var req = if (secure) {
            Https.request(options, function(res) {
                handleHttpResponse(res, onSuccess, onError);
            });
        } else {
            Http.request(options, function(res) {
                handleHttpResponse(res, onSuccess, onError);
            });
        };
        
        req.on("error", function(err) {
            onError("Request error: " + err);
        });
        
        req.end();
    }
    
    public static function handleHttpResponse(res: Dynamic, onSuccess: Bytes -> Void, onError: String -> Void): Void {
        //trace("Custom HTTP Status: " + res.statusCode);
        
        var data: Array<Buffer> = [];
        
        res.on("data", function(chunk: Buffer) {
            data.push(chunk);
        });
        
        res.on("end", function() {
            var buffer = data.length == 1 ? data[0] : Buffer.concat(data);
            var arrayBuffer = buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength);
            var bytes = haxe.io.Bytes.ofData(arrayBuffer);
            
            //trace("Custom HTTP received " + bytes.length + " bytes");
            onSuccess(bytes);
        });
        
        res.on("error", function(err) {
            onError("Network error: " + err);
        });
    }

    public static function createTolerantHttpRequest(url: String, onSuccess: Bytes -> Void, onError: String -> Void): Void {
        var http = new HttpNodeJs(url);
        var hasReceived = false;
        
        http.onBytes = function(data: Bytes) {
            hasReceived = true;
            onSuccess(data);
        };
        
        http.onError = function(error: String) {
            // Only report error if we haven't received any data
            if (!hasReceived) {
                onError(error);
            }
        };
        
        http.onStatus = function(status) {
            //trace("HTTP Status for " + url + ": " + status);
        };
        
        http.request();
    }

    public static function updateLibraries(platform: String) {
        var debugLibUrl = LibUrl.linuxDebug;
        var releaseLibUrl = LibUrl.linuxRelease;
        if (platform == "windows") {
            debugLibUrl = LibUrl.windowsDebug;
            releaseLibUrl = LibUrl.windowsRelease;
        }
        else if (platform == "macOS") {
            debugLibUrl = LibUrl.macDebug;
            releaseLibUrl = LibUrl.macRelease;
        }
        else if (platform == "linux") {
            debugLibUrl = LibUrl.linuxDebug;
            releaseLibUrl = LibUrl.linuxRelease;
        }
        else {
            return;
        }

        trace("Downloading: " + debugLibUrl);
        trace("Downloading: " + releaseLibUrl);

        var debugHttp = new HttpNodeJs(debugLibUrl);
        debugHttp.onError = function(error) {
            Sys.println("Error downloading debug libraries: " + error);
            Sys.exit(1);
        }

        var releaseHttp = new HttpNodeJs(releaseLibUrl);
        releaseHttp.onError = function(error) {
            Sys.println("Error downloading release libraries: " + error);
            Sys.exit(1);
        }

        debugHttp.onBytes = function(data:Bytes) {
            //trace("Debug archive size: " + data.length);
            // Check if this is an empty response due to redirect
            if (data.length == 0 && debugHttp.responseHeaders != null) {
                var location = debugHttp.responseHeaders.get("location");
                if (location != null) {
                    //trace("Debug redirect to: " + location);
                    downloadWithCustomHttp(location, 
                        function(redirectData:Bytes) {
                            //trace("Debug redirected archive size: " + redirectData.length);
                            extractArchive(redirectData, debugLibUrl);
                        },
                        function(error:String) {
                            Sys.println("Error downloading debug libraries (redirect): " + error);
                            Sys.exit(1);
                        }
                    );
                    return;
                }
            }
            extractArchive(data, debugLibUrl);
        };
        releaseHttp.onBytes = function(data:Bytes) {
            //trace("Release archive size: " + data.length);
            // Check if this is an empty response due to redirect
            if (data.length == 0 && releaseHttp.responseHeaders != null) {
                var location = releaseHttp.responseHeaders.get("location");
                if (location != null) {
                    //trace("Release redirect to: " + location);
                    downloadWithCustomHttp(location,
                        function(redirectData:Bytes) {
                            //trace("Release redirected archive size: " + redirectData.length);
                            extractArchive(redirectData, releaseLibUrl);
                        },
                        function(error:String) {
                            Sys.println("Error downloading release libraries (redirect): " + error);
                            Sys.exit(1);
                        }
                    );
                    return;
                }
            }
            extractArchive(data, releaseLibUrl);
        };

        debugHttp.onStatus = function(status) {
            trace("Debug HTTP Status: " + status);
        };
        releaseHttp.onStatus = function(status) {
            trace("Release HTTP Status: " + status);
        };

        debugHttp.request();
        releaseHttp.request();
    }

    public static function extractArchive(bytes: Bytes, url: String) {
        if (bytes.length == 0) {
            trace("Download failed: empty archive");
            return;
        }
        var cwd = Sys.getCwd();
        if (StringTools.endsWith(url, ".zip")) {
            var input = new BytesInput(bytes);
            var entries = Reader.readZip(input);
            if (!FileSystem.exists(cwd + "/template/lib/")) {
                FileSystem.createDirectory(cwd + "/template/lib/");
            }
            for (entry in entries) {
                if (!StringTools.startsWith(entry.fileName, "lib/")) {
                    continue;
                }
                var entryPath = cwd + "/template/" + entry.fileName;
                if (StringTools.contains(entryPath, "\\")) {
                    entryPath = StringTools.replace(entryPath, "\\", "/");
                }
                if (StringTools.endsWith(entryPath, "/") || StringTools.endsWith(entryPath, "\\") || !StringTools.contains(entryPath, ".")) {
                    Sys.println("Creating Directory: " + entryPath);
                    FileSystem.createDirectory(entryPath);
                    continue;
                }
                var stringArray = entryPath.split("/");
                var baseDir: String = "";
                for (i in 0...stringArray.length - 1) {
                    baseDir += stringArray[i] + "/";
                    checkDir(baseDir);
                }
                Sys.println("Updating File: " + entryPath);
                var entryBytes = entry.data;
                File.saveBytes(entryPath, entryBytes);
            }
        } else if (StringTools.endsWith(url, ".tar.gz")) {
            // Add tar.gz extraction logic here
            trace("Extracting tar.gz not implemented");
        } else {
            trace("Unknown archive format");
        }
    }

    public static function checkDir(path: String) {
        if (!FileSystem.exists(path)) {
            Sys.println("Creating Directory: " + path);
            FileSystem.createDirectory(path);
        }
    }
}