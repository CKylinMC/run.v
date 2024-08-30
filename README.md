# RUN!!

A simple task runner for Windows, inspired by Makefile.

This tool used to be a part of cmand (aka. `cmand task [taskname]`), and now fully rewrited in V.


## Installation

1. Download binary from release page.
2. Put any folder which in your system PATH variable.
3. Done.

## Usage

`run` does not have any configuration file or subcommands, just a few flags.

* `-c/--create` Create/override a new task file.
* `-?/--usage` Check help messages for a task if it have.
* `-a/--run-all` Run multiple tasks in one time.

And due to it's built on top of the cli.v module, it also have:

* `help/-help` Show help message.
* `version/-version` Show version information.
* `man/-man` Output usages in UNIX manual format.

In common, you command should be like:

```
run [flags] [taskname]
```

such as:

* `run -c` Create a new task file.
* `run -? sometask` Check help messages for a task.
* `run -a task1 task2 task3` Run multiple tasks in one time.

### `.cmandtask` file

When you use `run -c` or `run --create`, it will create a special file in current folder named `.cmandtask`, it's a task file that could be parsed by `run`.

`.cmandtask` file have two parts: `meta` zone and `tasks` zone.

#### Basic syntax

In file `.cmandtask`, any property will be defined in the format of `#key value`, some of them support multiple lines and you could write them like pair of `#keybegin` + blabla + `#keyend`.

All named section will be marked as `:sectionname` in the file. All properties defined after this section will be treated as the properties of this section.

All lines that starts with `//` and not in lone-line marks will be treated as comments.

All remaining lines will be content of its section.

#### `meta` Zone

On the top of the taskfile, it will define some special flags:

```
#version 2
#desc testfile contents
#bannerbegin
BANNER!!!!
#bannerend
#helpbegin
some custom help text here
#helpend
```

All supported properties for meta:

* `#version` The version of the task file, currently only support `2`. **That's the only required meta property in section `meta`**
* `#desc` The description of the task file.
* `#banner` or pair of `#bannerbegin` and `#bannerend` The banner text that will be shown when you run any command inside a taskfile.
* `help` or pair of `#helpbegin` and `#helpend` The help message overrides for your taskfile.

#### `tasks` Zone

After the zone `meta`, you could define your tasks in the `tasks` zone:

```
:taskApre
@echo off
echo taskApre

:taskApost
@echo off
echo taskApost

:taskA
#name Task A!
#desc A simple task!
#helpbegin
help here
#helpend
#pre taskApre
#post taskApost
#acceptparams true
#runmode default
#if-file-exists .cmandtask
@echo off
echo taskA
```

All tasks could be marked as `:taskname`, and all properties defined after this section will be treated as the properties of this task before next task section.

All supported properties for task:

* `name` Display name of this task
* `desc` Description of this task
* `help` Help message of this task (Also `#helpbegin` and `#helpend`)
* `pre` Pre-task name, will be executed before current task
* `post` Post-task name, will be executed after current task
* `runmode` Run mode, accept `shell`(default) or `tempfile`(create a temp file and run in current folder)

Sometimes you want your task only executed when some conditions are met, you could use `if-*` properties to define them:

* `if-exists [path]` Task will only be executed when the path exists
* `if-not-exists [path]` Task will only be executed when the path not exists
* `if-file-exists [path]` Task will only be executed when the file at the specified path exists.
* `if-file-not-exists [path]` Task will only be executed when the file at the specified path does not exist.
* `if-env-exists [variable]` Task will only be executed when the environment variable with the specified name exists.
* `if-env-not-exists [variable]` Task will only be executed when the environment variable with the specified name does not exist.
* `if-env-equals [variable=value]` Task will only be executed when the value of the environment variable with the specified name is equal to the specified value.
* `if-env-not-equals [variable=value]` Task will only be executed when the value of the environment variable with the specified name is not equal to the specified value.
* `if-folder-exists [path]` Task will only be executed when the folder at the specified path exists.
* `if-folder-not-exists [path]` Task will only be executed when the folder at the specified path does not exist.

Then any text not in the properties will be treated as the command to be executed. You can also quote your command in `#cmdbegin` and `#cmdend`, it also works.

### Example

Here is an example of a `.cmandtask` file:

```
#version 2
#desc testfile contents
#bannerbegin
BANNER!!!!
#bannerend
#helpbegin
taskA - Entry of tasks

You can run taskA directlly.
#helpend

:taskApre
@echo off
echo taskApre

:taskApost
@echo off
echo taskApost

:taskA
#name Task A!
#desc A simple task!
#helpbegin
Entry of the tasks
#helpend
#pre taskApre
#post taskApost
#acceptparams true
#runmode default
#if-file-exists .cmandtask
@echo off
echo taskA
```

And you got:
```
>run taskA
====================
BANNER!!!!
====================

Evaluating conditions for task: Task A!
Running task: Task A!
Executing pre-task: Task A!
Running task: taskApre
Executing task: taskApre
mode: tempfile
taskApre
Task exited with code: 0
Task taskApre finished in 62.000ms
Executing task: Task A!
mode: shell
Task exited with code: 0
Executing post-task: Task A!
Running task: taskApost
Executing task: taskApost
mode: tempfile
taskApost
Task exited with code: 0
Task taskApost finished in 35.000ms
Task Task A! finished in 129.000ms

```
