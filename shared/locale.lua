Locales = Locales or {}

local function getLocaleTable()
    return Locales[Config.Locale] or Locales['de'] or {}
end

function Locale(key, ...)
    local loc = getLocaleTable()
    local str = loc[key]

    if not str and Config.Locale ~= 'de' then
        str = Locales['de'] and Locales['de'][key]
    end

    if not str then
        return 'Missing locale: ' .. tostring(key)
    end

    if select('#', ...) > 0 then
        return string.format(str, ...)
    end

    return str
end

function LocaleUI()
    local loc = getLocaleTable()
    return loc.ui or {}
end

function LocaleDefaultQuestions()
    local loc = getLocaleTable()
    if loc.default_questions then
        return loc.default_questions
    end

    return Locales['de'] and Locales['de'].default_questions or {}
end
