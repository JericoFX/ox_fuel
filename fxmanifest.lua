fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

name 'ox_fuel'
author 'Overextended'
version '1.6.0'
repository 'https://github.com/JericoFX/ox_fuel'
description 'Advanced fuel management system with NPC service and emergency discounts'

dependencies {
	'ox_lib',
	'ox_inventory'
}

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua',
	'shared/*.lua'
}

server_scripts {
	'server.lua'
}

client_script 'client/init.lua'

files {
	'locales/*.json',
	'data/stations.lua',
	'client/*.lua',
	'shared/*.lua'
}

ox_libs {
	'math',
	'locale',
}
