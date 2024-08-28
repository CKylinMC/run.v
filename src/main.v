module main

import os
import cli
import term
import time
import rand

pub struct TaskCondition {
mut:
	condition string
	value	 string
}

pub struct Task {
mut:
	name         string
	desc         string
	help         string
	pre          string
	post         string
	acceptparams bool
	runmode      string
	cmd          string
	conditions   []TaskCondition
}

pub struct TaskManifest {
mut:
	version int
	desc    string
	banner  string
	help    string
	tasks   map[string]Task
}

pub struct Property {
	key   string
	value string
}

pub struct ParsedArg {
	options []string
	params  map[string]string
}

fn failed(str string) {
	eprintln(str)
	exit(1)
}

fn failed_with_time(str string, start_time time.Time) {
	eprintln("Failed after "+(time.now()-start_time).str()+": "+str)
	exit(1)
}

fn check_task_file() bool {
	return os.exists('.cmandtask') && os.is_file('.cmandtask')
}

fn load_file() string {
	return os.read_file('.cmandtask') or { failed("Failed to load file") }
}

fn parse_task_manifest(content string) TaskManifest {
	mut section := "___head_meta"
	mut mode := ""
	mut manifest := TaskManifest{
		version: 0,
		desc:    "",
		banner:  "",
		help:    "",
		tasks:   map[string]Task{},
	}
	mut current_task := Task{
		name:         "",
		desc:         "",
		help:         "",
		pre:          "",
		post:         "",
		acceptparams: false,
		runmode:      "default",
		cmd:          "",
		conditions:   []TaskCondition{},
	}
	mut lines := content.split_into_lines()
	for line in lines {
		mut trimmed := line.trim_indent()
		mut full_trimmed := line.trim_space()
		if full_trimmed == "" && mode == "" {
			continue
		}
		if section == "___head_meta" {
			if trimmed.starts_with(':'){
				if mode.len > 0 {
					failed("[meta] Invalid section: "+trimmed+" started while reading long property: "+mode)
				}
				section = trimmed.trim_left(':')
				current_task = Task{}
				continue
			}
			match mode {
				"help" {
					if trimmed.starts_with("#helpend") {
						mode = ""
					} else {
						manifest.help += line + "\n"
					}
				}
				"banner" {
					if trimmed.starts_with("#bannerend") {
						mode = ""
					} else {
						manifest.banner += line + "\n"
					}
				}
				else {
					if trimmed.starts_with("//") { continue }
					mut prop := parse_line(trimmed) or { failed("[meta] Invalid property in line: "+trimmed) break }
					match prop.key {
						"version" { manifest.version = prop.value.trim_space().int() }
						"desc"    { manifest.desc = prop.value }
						"banner"  { manifest.banner = prop.value }
						"help"    { manifest.help = prop.value }
						"bannerbegin" { mode = "banner" }
						"helpbegin" { mode = "help" }
						else { failed("[meta] Invalid property: "+prop.key) }
					}
				}
			}
		}else{
			if trimmed.starts_with(':'){
				if mode != "" {
					failed("[sect] Invalid section "+trimmed+" started while reading long property: "+mode)
				}

				if current_task.cmd != "" {
					if current_task.name.len == 0 {
						current_task.name = section
					}
					manifest.tasks[section] = current_task
				}

				section = trimmed.trim_left(':')
				current_task = Task{}
				continue
			}
			match mode {
				"help" {
					if trimmed.starts_with("#helpend") {
						mode = ""
					} else {
						current_task.help += line + "\n"
					}
				}
				"pre" {
					if trimmed.starts_with("#preend") {
						mode = ""
					} else {
						current_task.pre += line + "\n"
					}
				}
				"post" {
					if trimmed.starts_with("#postend") {
						mode = ""
					} else {
						current_task.post += line + "\n"
					}
				}
				else {
					if trimmed.starts_with("//") { continue }
					if !trimmed.starts_with('#') {
						current_task.cmd += line + "\n"
						continue
					}
					mut prop := parse_line(trimmed) or { failed("[sect] Invalid property in line: "+trimmed) return manifest }
					match prop.key {
						"name"         { current_task.name = prop.value }
						"desc"         { current_task.desc = prop.value }
						"help"         { current_task.help = prop.value }
						"pre"          { current_task.pre = prop.value }
						"post"         { current_task.post = prop.value }
						"acceptparams" { current_task.acceptparams = prop.value == "true" }
						"runmode"      {
							current_task.runmode = match prop.value {
								"default" { "default" }
								"shell"   { "shell" }
								"tempfile" { "tempfile" }
								else { failed("[sect] Invalid runmode: "+prop.value) "" }
							}
						}
						"if-exists" {current_task.conditions << [TaskCondition{condition: "exists", value: prop.value}]}
						"if-not-exists" {current_task.conditions << [TaskCondition{condition: "not-exists", value: prop.value}]}
						"if-file-exists" {current_task.conditions << [TaskCondition{condition: "file-exists", value: prop.value}]}
						"if-file-not-exists" {current_task.conditions << [TaskCondition{condition: "file-not-exists", value: prop.value}]}
						"if-env-exists" {current_task.conditions << [TaskCondition{condition: "env-exists", value: prop.value}]}
						"if-env-not-exists" {current_task.conditions << [TaskCondition{condition: "env-not-exists", value: prop.value}]}
						"if-env-equals" {current_task.conditions << [TaskCondition{condition: "env-equals", value: prop.value}]}
						"if-env-not-equals" {current_task.conditions << [TaskCondition{condition: "env-not-equals", value: prop.value}]}
						"if-folder-exists" {current_task.conditions << [TaskCondition{condition: "folder-exists", value: prop.value}]}
						"if-folder-not-exists" {current_task.conditions << [TaskCondition{condition: "folder-not-exists", value: prop.value}]}
						"helpbegin"    { mode = "help" }
						// "prebegin"     { mode = "pre" }
						// "postbegin"    { mode = "post" }
						"cmdbegin"     { mode = "cmd" }
						else { failed("[sect] Invalid property: "+prop.key) }
					}
				}
			}
		}
	}

	if mode != "" {
		failed("[end-] File ended unexcepted while reading long property: "+mode)
	}

	if current_task.cmd != "" {
		if current_task.name.len == 0 {
			current_task.name = section
		}
		manifest.tasks[section] = current_task
	}
	return manifest
}

fn parse_line(line string) ?Property {
	if !line.starts_with('#') {
		return none
	}
	mut trimmed_line := line.trim_left("#").trim_indent()
	mut idx := trimmed_line.index(' ') or { trimmed_line.len }
	mut key := trimmed_line.substr(0, idx)
	mut value := trimmed_line.substr(idx, trimmed_line.len).trim_space()
	return Property{key: key, value: value}
}

fn parse_args(cmd cli.Command) ! {
	if cmd.flags.get_bool("-create") or { false } {
		os.write_file('.cmandtask', "#version 2\n#desc This is a task file for cmand\n\n:hello\necho Helloworld!\n\n") or { failed("Failed to create task file") }
		println("Created new task file as '.cmandtask'")
		return
	}

	if !check_task_file() {
		if cmd.flags.get_bool("-usage") or { false } {
			cmd.execute_help()
		}
		failed("No task file found. Try 'run --create' to create a new task file.")
	}

	mut manifest := parse_task_manifest(load_file())
	if manifest.version != 2 {
		failed("Unsupported task file version: "+manifest.version.str()+", try use 'run --create' to re-create task file.")
	}

	if manifest.banner.len > 0 {
		println("=".repeat(20))
		println(manifest.banner.trim_space_right())
		println("=".repeat(20))
		println("")
	}

	if cmd.flags.get_bool("-usage") or { false } {
		if os.args.len > 2 {
			mut task_name := os.args[2]
			if task_name in manifest.tasks.keys() {
				mut task := manifest.tasks[task_name]
				mut name := task_name
				if task.name.len > 0 {
					name = task.name
				}
				println("Help of "+name)
				println(task.desc)
				println(task.help.trim_space_right())
			} else {
				println("Task not found: "+task_name)
			}
			return
		}
		if manifest.help.len > 0 {
			println("Help of taskfile: \n"+manifest.help.trim_space_right())
		} else {
			if manifest.tasks.len == 0 {
				println("No tasks found")
			} else {
				println("Help of all tasks:")
				for key, task in manifest.tasks {
					if task.help.len > 0 {
						println("\t"+key+": \n\t\t"+task.help.trim_space_right())
					} else {
						println("\t"+key+": No help found")
					}
				}
			}
		}
		return
	}

	if cmd.flags.get_bool("-run-all") or { false } {
		if os.args.len < 3 {
			failed("No tasks specified to run")
		}
		mut tasks := os.args[2..os.args.len].clone()
		for task_name in tasks {
			if task_name in manifest.tasks.keys() {
				mut task := manifest.tasks[task_name]
				execute_task(task, manifest) or { failed("Failed to run task: "+task_name) }
			} else {
				println("Task not found: "+task_name)
			}
		}

		return
	}

	if os.args.len > 1 {
		mut tasks := os.args[1..os.args.len].clone()
		for task_name in tasks {
			if task_name in manifest.tasks.keys() {
				mut task := manifest.tasks[task_name]
				execute_task(task, manifest) or { failed("Failed to run task: "+task_name) }
			} else {
				println("Task not found: "+task_name)
			}
		}

		return
	}

	// list all tasks and desc here
	if manifest.tasks.len == 0 {
		println("No tasks found")
		return
	}
	println("Available tasks:")
	for key, task in manifest.tasks {
		mut name := key
		mut desc := ""
		if task.name.len > 0 {
			name = key+" ("+task.name+")"
		}
		if task.desc.len > 0 {
			desc = task.desc
		}
		println("    "+name+"\n        "+desc)
	}
}

fn execute_task(task Task, manifest TaskManifest) ! {
	if !evaluate_conditions(task) {
		println(term.gray("Skipped task "+task.name+" due to conditions test failed"))
		return
	}
	mut start_time := time.now()
	println(term.cyan("Running task: "+task.name))
	if task.pre.len > 0 {
		println(term.gray("Executing pre-task: "+task.name))
		if task.pre in manifest.tasks.keys() {
			mut pre_task := manifest.tasks[task.pre]
			execute_task(pre_task, manifest) or { failed_with_time("pre-task: "+task.pre, start_time) }
		} else {
			failed_with_time("Pre-task not found: "+task.pre, start_time)
		}
	}
	println(term.gray("Executing task: "+task.name))
	match task.runmode {
		"default", "shell", "" {
			execute_as_shell(task.cmd) or { failed_with_time(task.name, start_time) panic("Aborted") }
		}
		"tempfile" {
			execute_as_tempfile(task.cmd) or { failed_with_time(task.name, start_time) panic("Aborted") }
		}
		else {
			failed_with_time("Unsupported runmode: "+task.runmode, start_time) panic("Aborted")
		}
	}
	if task.post.len > 0 {
		println(term.gray("Executing post-task: "+task.name))
		if task.post in manifest.tasks.keys() {
			mut post_task := manifest.tasks[task.post]
			execute_task(post_task, manifest) or { failed_with_time("post-task: "+task.post, start_time) }
		} else {
			failed_with_time("Post-task not found: "+task.post, start_time)
		}
	}
	println(term.green("Task "+task.name+" finished in "+(time.now()-start_time).str()))
}

fn execute_as_shell(cmd string) !int {
	println(term.gray("mode: shell"))
	mut result := os.system(cmd)
	if result != 0 {
		eprintln("Task exited with code: "+result.str())
		panic("Exit with code: "+result.str())
	}
	println(term.gray("Task exited with code: "+result.str()))
	return result
}

fn execute_as_tempfile(cmd string) !int {
	println(term.gray("mode: tempfile"))
	mut filename := ".cmandtask_temp_"+rand.string(10)+".cmd"
	os.write_file(filename, cmd) or {
		eprintln("Failed to create tempfile")
		panic("Failed to create tempfile")
	 }
	mut result := os.system(filename)
	os.rm(filename) or {
		eprintln("Failed to remove tempfile")
		panic("Failed to remove tempfile")
	}
	if result != 0 {
		eprintln("Task exited with code: "+result.str())
		panic("Exit with code: "+result.str())
	}
	println(term.gray("Task exited with code: "+result.str()))
	return result
}

fn evaluate_conditions(task Task) bool {
	if task.conditions.len == 0 {
		return true
	}
	println(term.gray("Evaluating conditions for task: "+task.name))
	for condition in task.conditions {
		if !evaluate_condition(condition, task) {
			println(term.gray("Condition failed: "+condition.condition+" "+condition.value))
			return false
		}
	}
	return true
}

fn evaluate_condition(condition TaskCondition, task Task) bool {
	match condition.condition{
		"exists" {
			return os.exists(condition.value)
		}
		"not-exists" {
			return !os.exists(condition.value)
		}
		"file-exists" {
			return os.exists(condition.value) && os.is_file(condition.value)
		}
		"file-not-exists" {
			return !os.exists(condition.value) || !os.is_file(condition.value)
		}
		"env-exists" {
			return os.getenv(condition.value).len > 0
		}
		"env-not-exists" {
			return os.getenv(condition.value).len == 0
		}
		"env-equals" {
			mut parts := condition.value.split("=")
			if parts.len != 2 {
				failed("Invalid env-equals condition: "+condition.value)
			}
			mut env_name := parts[0]
			mut env_value := parts[1]
			return os.getenv(env_name) == env_value
		}
		"env-not-equals" {
			mut parts := condition.value.split("=")
			if parts.len != 2 {
				failed("Invalid env-not-equals condition: "+condition.value)
			}
			mut env_name := parts[0]
			mut env_value := parts[1]
			return os.getenv(env_name) != env_value
		}
		"folder-exists" {
			return os.exists(condition.value) && os.is_dir(condition.value)
		}
		"folder-not-exists" {
			return !os.exists(condition.value) || !os.is_dir(condition.value)
		}
		else {
			failed("Unsupported condition: "+condition.condition)
		}
	}
	return false
}

fn main() {
	// if check_task_file() {
	// 	mut content := load_file()
	// 	mut manifest := parse_task_manifest(content)
	// 	println("Version: " + manifest.version.str())
	// 	println("Desc: " + manifest.desc)
	// 	println("Banner: " + manifest.banner)
	// 	println("Help: " + manifest.help)
	// 	for key, task in manifest.tasks {
	// 		println("Task: " + key)
	// 		println("Name: " + task.name)
	// 		println("Desc: " + task.desc)
	// 		println("Help: " + task.help)
	// 		println("Pre: " + task.pre)
	// 		println("Post: " + task.post)
	// 		println("Accept Params: " + task.acceptparams.str())
	// 		println("Run Mode: " + task.runmode)
	// 		println("Cmd: " + task.cmd)
	// 	}
	// } else {
	// 	println("No task file found")
	// }

	mut app := cli.Command{
		name: "run"
		description: "This is 'run' (aka. cmand task runner).\nA simple task runner written in V by CKylinMC, inspired by Makefile."
		version: "0.1.0"
		execute: parse_args
		flags: [
			cli.Flag{
				flag: .bool
				name: "-create",
				description: "Create/override a new task file",
				abbrev: "c",
			}
			cli.Flag{
				flag: .bool
				name: "-usage",
				description: "Check usage of the task file",
				abbrev: "?",
			}
			cli.Flag{
				flag: .bool
				name: "-run-all",
				description: "Run multiple tasks in one time.",
				abbrev: "a",
			}
		]
	}
	app.setup()
	app.parse(os.args)
}
