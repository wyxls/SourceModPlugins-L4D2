Description

To trigger name changing before game start, you need to add `sm_hostname` in `cfg/sourcemod/server.cfg` .

This plugin will automatically change hostname and supports unicode characters (like simplified Chinese). It also supports multiple servers.

Configuration

```json
"Settings"
{
	"HostName"
	{
		// ONLY use these two settings below if you want to display the hostname with Unicode characters. (e.g. Simplified Chinese)
		// Reading Unicode characters from a ".cfg" file does not seem to work, so this is the workaround.
	
		// Hostname used by the {hostname} tag.
		"{HostName}#01"							"[Zakikun]高级难度房#1"
		"{HostName}#02"							"[Zakikun]高级难度房#2"
		"{HostName}#03"							"[Zakikun]高级难度房#3"
	}
}
```

Server hostname must be matched with "{HostName#xx}" to automatically change into new name.

e.g. "{HostName}#01" will be changed to "[Zakikun]高级难度房#1" and "{HostName}#02" will be changed to "[Zakikun]高级难度房#2".
