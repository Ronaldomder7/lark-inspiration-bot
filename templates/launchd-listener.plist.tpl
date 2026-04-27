<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.lark-inspiration-bot.listener</string>

    <key>ProgramArguments</key>
    <array>
        <string>{{PROJECT_ROOT}}/scripts/listener.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>StandardOutPath</key>
    <string>{{PROJECT_ROOT}}/logs/listener.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>{{PROJECT_ROOT}}/logs/listener.stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>{{USER_PATH}}</string>
    </dict>
</dict>
</plist>
