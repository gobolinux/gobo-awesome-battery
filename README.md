gobo-awesome-battery
====================

A battery widget for Awesome WM. This widget was created for [https://gobolinux.org](GoboLinux).

Requirements
------------

* Awesome 3.5+
* the Linux /sys filesystem

Using
-----

Require the module:


```
local battery = require("gobo.awesome.battery")
```

Create the widget with `battery.new()` and add to your layout.
In a typical `rc.lua` this will look like this:


```
right_layout:add(battery.new())
```

