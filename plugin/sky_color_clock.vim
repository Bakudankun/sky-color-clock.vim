"=============================================================================
" File: sky_color_clock.vim
" Author: mopp
" Created: 2018-01-18
"=============================================================================

vim9script
scriptencoding utf-8

if exists('is_loaded')
    finish
endif
const is_loaded = true


import autoload 'sky_color_clock.vim' as sky

# Local immutable variables.
const PI = 3.14159265359


# degrees = radian * 180 / pi.
def RadToDeg(r: float): float
    return r * 180.0 / PI
enddef


# radian = degrees * pi / 180.
def DegToRad(d: float): float
    return d * PI / 180.0
enddef


def GetSunsetTimeFromNoon(timestamp: number): float
    const current_year = str2nr(strftime('%Y', timestamp))
    const leap_count   = count(map(range(1970, current_year - 1), (_, val: number) => val % 400 == 0 || (val % 4 == 0 && val % 100 != 0)), 1)
    const day_of_year  = float2nr(timestamp / (24 * 60 * 60)) % 365 - leap_count - 1

    const latitude          = DegToRad(g:sky_color_clock#latitude)
    const sun_declination   = DegToRad(-23.44 * (cos(DegToRad((360 / 365.0) * (day_of_year + 10)))))
    const sunset_hour_angle = acos(-1 * tan(latitude * tan(sun_declination)))
    return 24.0 * (RadToDeg(sunset_hour_angle) / 360.0)
enddef


def DefaultColorStops(timestamp: number): list<tuple<float, string>>
    const sunset_time_from_noon = GetSunsetTimeFromNoon(timestamp)
    const sunrise               = 12 - sunset_time_from_noon
    const sunset                = 12 + sunset_time_from_noon
    return [
        (sunrise - 2.0,          "#111111"),
        (sunrise - 1.5,          "#4d548a"),
        (sunrise - 1.0,          "#c486b1"),
        (sunrise - 0.5,          "#ee88a0"),
        (sunrise,                "#ff7d75"),
        (sunrise + 0.5,          "#f4eeef"),
        ((sunset + sunrise) / 2, "#8bd7f5"),
        (sunset - 1.2,           "#b3f2e6"),
        (sunset - 0.8,           "#f3e693"),
        (sunset - 0.4,           "#f86b10"),
        (sunset,                 "#100028"),
        (sunset + 0.5,           "#111111"),
    ]
enddef


# Define global variables.
g:sky_color_clock#latitude                = get(g:, 'sky_color_clock#latitude', 35)
g:sky_color_clock#color_stops             = get(g:, 'sky_color_clock#color_stops', DefaultColorStops(localtime()))
g:sky_color_clock#datetime_format         = get(g:, 'sky_color_clock#datetime_format', '%d %H:%M')
g:sky_color_clock#enable_emoji_icon       = get(g:, 'sky_color_clock#enable_emoji_icon', has('mac'))
g:sky_color_clock#temperature_color_stops = get(g:, 'sky_color_clock#temperature_color_stops', [
    (263, '#00a1ff'),
    (288, '#ffffff'),
    (313, '#ffa100')
])

g:sky_color_clock#openweathermap_api_key = get(g:, 'sky_color_clock#openweathermap_api_key', exists('$OPENWEATHERMAP_API_KEY') ? expand('$OPENWEATHERMAP_API_KEY') : '')
g:sky_color_clock#openweathermap_city_id = get(g:, 'sky_color_clock#openweathermap_city_id', '1850144')


# for preload.
augroup sky_color_clock
    autocmd ColorScheme * sky.Statusline()
    if !empty(g:sky_color_clock#openweathermap_api_key)
        autocmd ColorScheme * sky.DefineTemperatureHighlight()
    endif
augroup END
