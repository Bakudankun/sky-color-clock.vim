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


# Local immutable variables.
const moonphase_cycle = 29.5306 # Eclipse (synodic month) cycle in days.
const new_moon_base_timestamp = 6.8576 # A new moon (1970/01/08 05:35) in days since the epoch.
const moonphase_emojis = [
    ( 1.84, '🌑'),
    ( 5.53, '🌒'),
    ( 9.22, '🌓'),
    (12.91, '🌔'),
    (16.61, '🌕'),
    (20.30, '🌖'),
    (23.99, '🌗'),
    (27.68, '🌘'),
]
# Dictionary whose keys are filenames of OpenWeatherMap's weather icons
const weather_emojis = {
    '01d': '☀', '01n': '🌙',
    '02d': '☀', '02n': '🌙',
    '03d': '☁', '03n': '☁',
    '04d': '☁', '04n': '☁',
    '09d': '☂', '09n': '☂',
    '10d': '☂', '10n': '☂',
    '11d': '⚡', '11n': '⚡',
    '13d': '☃', '13n': '☃',
    '50d': '🌫️', '50n': '🌫️',
}


# https://github.com/Qix-/color-convert/blob/427cbb70540bb9e5b3e94aa3bb9f97957ee5fbc0/conversions.js#L555-L580
# https://stackoverflow.com/a/39277954
# https://stackoverflow.com/a/41978310
# https://github.com/tmux/tmux/blob/591b26e46f48f2e6b59f97e6cfb037c6fec48e15/colour.c#L57
# string -> number.
const q2c = (0, 0x5f, 0x87, 0xaf, 0xd7, 0xff)
def ToAnsi256Color(rgbstr: string): number
    const rgb = ParseRgb(rgbstr)
    const r = float2nr(rgb[0] * 255.0)
    const g = float2nr(rgb[1] * 255.0)
    const b = float2nr(rgb[2] * 255.0)

    const qr = ColorTo6Cube(r)
    const qg = ColorTo6Cube(g)
    const qb = ColorTo6Cube(b)
    const cr = q2c[qr]
    const cg = q2c[qg]
    const cb = q2c[qb]

    if cr == r && cg == g && cb == b
        return (16 + (36 * qr) + (6 * qg) + qb)
    endif

    const grey_avg   = (r + g + b) / 3
    const gray_index = 238 < grey_avg ? 23 : (grey_avg - 3) / 10
    const grey       = 8 + 10 * gray_index

    const rgbnum       = (r, g, b)
    const color_err = DistSq(rgbnum, (cr, cg, cb))
    const gray_err  = DistSq(rgbnum, (grey, grey, grey))

    return color_err <= gray_err ? (16 + (36 * qr + 6 * qg + qb)) : (232 + gray_index)
enddef


def DistSq(v1: tuple<number, number, number>, v2: tuple<number, number, number>): float
    var sum: float = 0.0
    for i in range(3)
        sum += pow(v1[i] - v2[i], 2)
    endfor

    return sum
enddef


def ColorTo6Cube(v: number): number
    return v < 48 ? 0 : v < 114 ? 1 : (v - 35) / 40
enddef


type Color = tuple<float, float, float>

# https://stackoverflow.com/questions/2353211/hsl-to-rgb-color-conversion
# [float] -> [float].
def RgbToHsl(rgb: Color): Color
    var max = 0.0
    var min = 1.0
    for c in rgb
        if max < c
            max = c
        endif
        if c < min
            min = c
        endif
    endfor

    const l = (max + min) / 2.0
    const delta = max - min

    if abs(delta) <= 1.0e-10
        return (0.0, 0.0, l)
    endif

    const s = (l <= 0.5) ? (delta / (max + min)) : (delta / (2.0 - max - min))

    const [r, g, b] = rgb
    const rc = (max - r) / delta
    const gc = (max - g) / delta
    const bc = (max - b) / delta

    var h: float
    if max == r
        h = bc - gc
    elseif max == g
        h = 2.0 + rc - bc
    else
        h = 4.0 + gc - rc
    endif

    h = fmod(h / 6.0, 1.0)

    if h < 0.0
        h = 1.0 + h
    endif

    return (h, s, l)
enddef


def HueToRgb(p: float, q: float, h: float): float
    const t = 1.0 < h ? h - 1.0 :
        h < 0.0       ? h + 1.0 :
        h

    return t < 1.0 / 6.0 ? p + (q - p) * 6.0 * t :
        t < 1.0 / 2.0    ? q :
        t < 2.0 / 3.0    ? p + (q - p) * (2.0 / 3.0 - t) * 6.0 :
        p
enddef


def HslToRgb(hsl: Color): Color
    const [h, s, l] = hsl

    const q = l <= 0.5 ? l * (1.0 + s) : l + s - l * s
    const p = 2.0 * l - q
    const r = HueToRgb(p, q, h + 1.0 / 3.0)
    const g = HueToRgb(p, q, h)
    const b = HueToRgb(p, q, h - 1.0 / 3.0)

    return (r, g, b)
enddef


# https://hail2u.net/blog/software/convert-hex-color-to-functional-color-with-vim.html
# (string) -> [float].
def ParseRgb(rgb: string): Color
    const rgblist = matchlist(rgb, '\c\([0-9A-F]\{2\}\)\([0-9A-F]\{2\}\)\([0-9A-F]\{2\}\)')[1 : 3]
    return mapnew(rgblist, (_, val) => str2nr(val, 16) / 255.0)->list2tuple()
enddef


# (float, float, float) -> string.
def ToRgbString(rgb: Color): string
    const r = float2nr(ceil(rgb[0] * 255.0))
    const g = float2nr(ceil(rgb[1] * 255.0))
    const b = float2nr(ceil(rgb[2] * 255.0))
    return printf('#%02x%02x%02x', r, g, b)
enddef


# (string, string, float) -> string.
def BlendColor(base_color: string, mix_color: string, fraction: float): string
    const x = fraction == 0.0 ? 0.5 : fraction
    const y = 1.0 - x

    const [r1, g1, b1] = ParseRgb(base_color)
    const [r2, g2, b2] = ParseRgb(mix_color)

    const r = (r1 * y) + (r2 * x)
    const g = (g1 * y) + (g2 * x)
    const b = (b1 * y) + (b2 * x)

    return ToRgbString((r, g, b))
enddef


def MakeGradient(color_stops: list<tuple<float, string>>, x: float): string
    const first_color = color_stops[0]
    if x <= first_color[0]
        return first_color[1]
    endif

    var last_color = color_stops[0]
    for next_color in color_stops
        if x <= next_color[0]
            const fraction = ((x - last_color[0]) / (next_color[0] - last_color[0]))
            return BlendColor(last_color[1], next_color[1], fraction)
        endif
        last_color = next_color
    endfor

    return color_stops[-1][1]
enddef


def PickBgColor(timestamp: number): string
    const [sec, min, hour] = split(strftime('%S,%M,%H', timestamp), ',')->map((_, v) => str2nr(v))
    const t = sec / 60.0
    const x = ((t + min) / 60.0) + hour

    var bg_color = MakeGradient(g:sky_color_clock#color_stops, x)

    if !!weather_info
        const cloudiness = weather_info.clouds.all / 100.0
        var [h, s, l] = RgbToHsl(ParseRgb(bg_color))
        s = s - (s * cloudiness * 0.9)
        l = l + cloudiness * 0.15
        l = (l > 0.95) ? 0.95 : l
        bg_color = ToRgbString(HslToRgb((h, s, l)))
    endif

    return bg_color
enddef


def PickFgColor(bg_color: string): string
    const [h, s, l] = RgbToHsl(ParseRgb(bg_color))
    var new_l = l + (0.5 < l ? -0.55 : 0.55)
    new_l = new_l < 0.0 ? 0.0 :
        1.0 < new_l ? 1.0 : new_l

    return ToRgbString(HslToRgb((h, s, new_l)))
enddef


def GetEmojiMoonphase(timestamp: number): string
    const time_in_days = timestamp / (24.0 * 60.0 * 60.0)
    const current_phase = fmod(time_in_days - new_moon_base_timestamp, moonphase_cycle)

    for [phase, emoji] in moonphase_emojis
        if current_phase <= phase
            return emoji
        endif
    endfor

    return moonphase_emojis[-1][1]
enddef


def GetSkyColors(timestamp: number): tuple<string, string, number, number>
    const bg = PickBgColor(timestamp)
    const fg = PickFgColor(bg)

    # Convert the RGB string into ANSI 256 color.
    const bg_t = ToAnsi256Color(bg)
    const fg_t = ToAnsi256Color(fg)

    return (fg, bg, fg_t, bg_t)
enddef


def ApplySkyColors(timestamp: number)
    const [fg, bg, fg_t, bg_t] = GetSkyColors(timestamp)
    :execute printf('hi SkyColorClock guifg=%s guibg=%s ctermfg=%d ctermbg=%d ', fg, bg, fg_t, bg_t)
enddef


var last_update_timestamp = 0
export def Statusline(): string
    const now = get(g:, 'sky_color_clock#timestamp_force_override', localtime())

    if now > last_update_timestamp + 60
        last_update_timestamp = now
        ApplySkyColors(now)
    endif

    var statusline = strftime(g:sky_color_clock#datetime_format, now)

    if g:sky_color_clock#enable_emoji_icon != 0
        var weather_icon: string
        if !!weather_info
            weather_icon = weather_emojis[weather_info.weather[0].icon]
            if weather_icon == '🌙'
                weather_icon = GetEmojiMoonphase(now)
            endif
        else
            weather_icon = GetEmojiMoonphase(now)
        endif
        statusline = printf("%s %s", weather_icon, statusline)
    endif

    return statusline
enddef


export def Preview()
    const now = localtime()
    const base_timestamp = (now - (now % (24 * 60 * 60))) - (9 * 60 * 60)

    :tabnew
    :syntax clear

    var cnt = 0
    var last_colors = GetSkyColors(base_timestamp)
    for h in range(0, 23)
        for m in range(0, 55, 5)
            const t = base_timestamp + (h * 60 * 60) + (m * 60)

            const colors = GetSkyColors(t)

            if last_colors == colors
                continue
            endif

            last_colors = colors
            const [fg, bg, fg_t, bg_t] = colors
            const str = strftime(g:sky_color_clock#datetime_format, t)

            append(cnt, str)

            const group_name = printf('SkyColorClockPreview%d', cnt)
            :execute printf('hi %s guifg=%s guibg=%s ctermfg=%d ctermbg=%d', group_name, fg, bg, fg_t, bg_t)
            :execute printf('syntax keyword %s %s', group_name, escape(str, '/ '))
            :execute printf('syntax match %s /%s/', group_name, escape(str, '/ '))

            ++cnt
        endfor
    endfor
enddef


def FetchCurrentWeatherInfo(Callback: func<string>)
    var cmd: string
    if executable('curl')
        cmd = 'curl --silent '
    elseif executable('wget')
        cmd = 'wget -q -O - '
    else
        throw 'curl and wget is not found !'
    endif


    var uri = printf('http://api.openweathermap.org/data/2.5/weather?id=%s&appid=%s',
        g:sky_color_clock#openweathermap_city_id,
        g:sky_color_clock#openweathermap_api_key)

    const quote = &shellxquote ==# '"' ?  "'" : '"'
    uri = quote .. uri .. quote

    if has('job')
        job_start(cmd .. uri, {'out_cb': (ch, out) => Callback(out)})
    else
        Callback(system(cmd .. shellescape(uri)))
    endif
enddef


export def DefineTemperatureHighlight(..._: list<any>)
    try
        FetchCurrentWeatherInfo(ApplyCurrentWeatherInfo)
    catch /.*/
        # :echomsg 'sky-color:exception:'.v:exception
    endtry
enddef


var weather_info: dict<any>
def ApplyCurrentWeatherInfo(json_string: string)
    weather_info = json_decode(json_string)

    const now = get(g:, 'sky_color_clock#timestamp_force_override', localtime())
    ApplySkyColors(now)

    const temp = weather_info.main.temp

    const bg = MakeGradient(g:sky_color_clock#temperature_color_stops, temp)
    const bg_t = ToAnsi256Color(bg)
    :execute printf('hi SkyColorClockTemp guibg=%s ctermbg=%d ', bg, bg_t)
enddef


if !empty(g:sky_color_clock#openweathermap_api_key)
    if has('timers')
        timer_start(1000 * 60 * 15, DefineTemperatureHighlight, {repeat: -1})
    endif
endif

const enable_test = 0
if enable_test
    assert_equal('#000000', ToRgbString(HslToRgb((0.0, 0.0, 0.0))))
    assert_equal('#ffffff', ToRgbString(HslToRgb((0.0, 0.0, 1.0))))
    assert_equal('#ff0000', ToRgbString(HslToRgb((0.0, 1.0, 0.5))))
    assert_equal('#00ff00', ToRgbString(HslToRgb((120.0 / 360.0, 1.0, 0.5))))
    assert_equal('#0000ff', ToRgbString(HslToRgb((240.0 / 360.0, 1.0, 0.5))))
    assert_equal('#ffff00', ToRgbString(HslToRgb((60.0 / 360.0, 1.0, 0.5))))
    assert_equal('#00ffff', ToRgbString(HslToRgb((180.0 / 360.0, 1.0, 0.5))))
    assert_equal('#ff00ff', ToRgbString(HslToRgb((300.0 / 360.0, 1.0, 0.5))))
    assert_equal('#c0c0c0', ToRgbString(HslToRgb((0.0, 0.0, 0.75))))
    assert_equal('#808080', ToRgbString(HslToRgb((0.0, 0.0, 0.50))))
    assert_equal('#800000', ToRgbString(HslToRgb((0.0, 1.0, 0.25))))
    assert_equal('#808000', ToRgbString(HslToRgb((60.0 / 360.0, 1.0, 0.25))))
    assert_equal('#008000', ToRgbString(HslToRgb((120.0 / 360.0, 1.0, 0.25))))
    assert_equal('#800080', ToRgbString(HslToRgb((300.0 / 360.0, 1.0, 0.25))))
    assert_equal('#008080', ToRgbString(HslToRgb((180.0 / 360.0, 1.0, 0.25))))
    assert_equal('#000080', ToRgbString(HslToRgb((240.0 / 360.0, 1.0, 0.25))))

    # call assert_equal([0.0,           0.0, 0.00], s:rgb_to_hsl(s:parse_rgb('#000000')))
    # call assert_equal([0.0,           0.0, 1.00], s:rgb_to_hsl(s:parse_rgb('#ffffff')))
    # call assert_equal([0.0,           1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#ff0000')))
    # call assert_equal([120.0 / 360.0, 1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#00ff00')))
    # call assert_equal([240.0 / 360.0, 1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#0000ff')))
    # call assert_equal([60.0 / 360.0,  1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#ffff00')))
    # call assert_equal([180.0 / 360.0, 1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#00ffff')))
    # call assert_equal([300.0 / 360.0, 1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#ff00ff')))
    # call assert_equal([0.0,           0.0, 0.75], s:rgb_to_hsl(s:parse_rgb('#c0c0c0')))
    # call assert_equal([0.0,           0.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#808080')))
    # call assert_equal([0.0,           1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#800000')))
    # call assert_equal([60.0 / 360.0,  1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#808000')))
    # call assert_equal([120.0 / 360.0, 1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#008000')))
    # call assert_equal([300.0 / 360.0, 1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#800080')))
    # call assert_equal([180.0 / 360.0, 1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#008080')))
    # call assert_equal([240.0 / 360.0, 1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#000080')))

    assert_equal('🌑', GetEmojiMoonphase(592500))
    assert_equal('🌑', GetEmojiMoonphase(1516155430))
    assert_equal('🌓', GetEmojiMoonphase(1516846630))

    if !empty(v:errors)
        for err in v:errors
            :echoerr string(err)
        endfor
    endif
endif
