fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bw_souscaisse'
author 'kairoxx'
description 'Se cacher sous une voiture garée (ox_lib + ox_target)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'locales/fr.lua',
    'locales/en.lua',
    'config.lua',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'ox_lib',
    'ox_target',
}