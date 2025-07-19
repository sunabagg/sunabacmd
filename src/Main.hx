package;

import haxe.Exception;
import sunaba.App;
import sunaba.core.io.Console;
import sunaba.core.Vector;
import sunaba.Error;
import sunaba.core.io.ConsoleCmd;
import sunaba.input.InputEvent;

class Main extends App {
    public static var singleton: Main;

    public var console: Console;

    private var commandHistory = new Array<String>();
    private var luaCommandHistory = new Array<String>();

    var inputMode = InputMode.lua;

    public static function main() {
        try {
            new Main();
        }
        catch (e: Exception) {
            trace(e);
        }
    }

    public var exitNow: Bool = false;

    public var isInputActive = true;

    override function init() {
        singleton = this;

        console = new Console();
        console.ioInterface = untyped __lua__("_G.ioInterface");
        rootElement.addChild(console);
        console.logHandler = (log: String) -> {
            Sys.println(log);
        }

        console.addCommand("hello-world", (args: Vector<String>) -> {
            console.eval('print("Hello, World!")');
            return Error.ok;
        });
        console.addCommand("echo", (args: Vector<String>) -> {
            var arr = args.toArray();
            if (arr.length > 0) {
                var text = arr.join(" ");
                console.print(text);
            } else {
                console.print("Usage: echo <text>");
            }
            return Error.ok;
        });
        console.addCommand("com", (args: Vector<String>) -> {
            try {
                var arr = args.toArray();
                if (arr.length == 1) {
                    var command = arr[0];
                    ConsoleCmd(command, console);
                    return Error.ok;
                } else {
                    console.print("Usage: com <command>");
                    return Error.ok;
                }
            }
            catch (e:Exception) {
                trace("Command parse error");
                console.printErr(e.toString());
            }

            return Error.failed;
        });
        console.addCommand("exit", (args: Vector<String>) -> {
            App.exit();
            return 0;
        });
        console.addCommand("cmode", (args: Vector<String>) -> {
            inputMode = InputMode.command;
            return 0;
        });
        console.addCommand("clear", (args: Vector<String>) ->  {
            clear();
            return 0;
        });
        console.currentDir = "app://";

        console.eval("_G.com = function(command) _G.cmd('com', A(command)) end");
        console.eval("_G.c = function(command) _G.cmd('com', A(command)) end");
        console.eval("_G.exit = function() _G.cmd('exit', A()) end");
        console.eval("_G.cmode = function() _G.cmd('cmode', A()) end");
        console.eval("_G.clear = function() _G.cmd('clear', A()) end");
        console.eval("cd('app://')"); // Set the initial working directory

        clear();
        console.print("Sunaba Command Shell");
        console.print("");
        printraw("sunabacmd:" + console.currentDir + "$ ");

        var inputFunc = this.onInputRecieved;
        untyped __lua__("_G.stdin = inputFunc");

        console.scriptInstance = this;
    }

    function clear() {
        //untyped __lua__("_G.__clearScreen()"); //
        if (Sys.systemName() == "Windows") {
            printraw("\x1b[2J\x1b[H");
            return;
        }
        printraw("\033[2J");
        printraw("\u001b[H");
        //printraw("\033c");
    }

    function printraw(string: String) {
        //var __str__ = str;
        untyped __lua__("_G.printraw(string)");
    }

    function stdin(): String {
        return untyped __lua__("_G.__stdinput");
    }

    public function process(delta: Float) {
        
        //Sys.println(stdin());
    }

    public function onInputRecieved(input: String) {
        if (input == "" || input == null)
            return;
        if (inputMode == InputMode.lua) {
            readln(input);
        }
        else if (inputMode == InputMode.command) {
            readln_cmode(input);
        }
    }

    public function readln_cmode(input: String) {
        commandHistory.push(input);
        if (input != "luamode") {
            try {
                ConsoleCmd(input, console);
                if (input == "exit")
                return;
                printraw("sunabacmd:" + console.currentDir + "$ ");
            }
            catch (e) {
            }
        }
        else {
            inputMode = InputMode.lua;
        }
    }

    public function readln(input: String) {
        if (input == "" || input == null)
            return;
        luaCommandHistory.push(input);
        if (input == "cmode" || input == "exit" || input == "clear")
            input += "()";
        try {
            console.eval(input);
            if (input == "exit()")
                return;
            printraw("sunabacmd:" + console.currentDir + "$ ");
        }
        catch (e) {
        }
    }
}