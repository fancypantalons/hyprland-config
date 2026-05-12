#!/usr/bin/ruby

require 'json'

def clients = JSON.parse(`hyprctl clients -j`)
def firefox = clients.detect { |c| c['class'] == 'firefox-nightly' }
def devtools = clients.detect { |c| c['class'] == 'firefox-nightly' && c['title'].start_with?('Developer Tools') }

def devtools_specialed? = devtools&.dig('workspace')&.dig('name')&.match?('special:devtools')

if !firefox.nil? && devtools.nil?
  system("hyprctl dispatch 'sendshortcut CTRL SHIFT, i, class:firefox-nightly'")
end

while devtools.nil?
  sleep 0.05
end

if !devtools_specialed?
  system("hyprctl dispatch 'movetoworkspace special:devtools, title:^(Developer Tools.*)$'")
else
  system("hyprctl dispatch togglespecialworkspace devtools")
end
