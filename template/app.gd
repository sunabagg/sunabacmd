extends App

var theme: Theme

signal line_received(line: String)

var input_thread: Thread

var input_thread_active = true

func _init() -> void:
	init_state(false)
	on_exit.connect(func():
		get_tree().quit()
	)
	
	
	input_thread = Thread.new()
	input_thread.start(Callable(self, "_stdin_reader"))

func _ready() -> void:
	args = OS.get_cmdline_args()
	var root_path : String = ProjectSettings.globalize_path("res://")
	if (!OS.has_feature("editor")):
		root_path = OS.get_executable_path().get_base_dir()
		if (OS.get_name() == "macOS"):
			root_path = root_path.replace("MacOS", "Resources")
		elif (OS.get_name() == "Linux"):
			var share_path = OS.get_executable_path().replace("bin/sunabacmd", "share/sunaba")
			print(share_path)
			if (DirAccess.dir_exists_absolute(share_path)):
				root_path = share_path
	
	if not root_path.ends_with("/"):
		root_path += "/"
	
	var sbx_path := root_path + "sunabacmd.sbx"
	load_and_execute_sbx(sbx_path)

func _stdin_reader(userdata=null):
	while true:
		var line = OS.read_string_from_stdin(1024)
		call_deferred("_on_line_recived", line)
		if line == "exit" or line == "exit()":
			break
		if not input_thread_active:
			break
	return null

func _on_line_recived(line: String):
	std_input = line

func is_input_active():
	return input_thread_active

func _exit_tree() -> void:
	if input_thread.is_alive():
		input_thread_active = false
		input_thread.wait_to_finish()
