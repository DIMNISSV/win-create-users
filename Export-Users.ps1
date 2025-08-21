<#
.SYNOPSIS
    Экспортирует список локальных пользователей в текстовый файл,
    генерируя для каждого новый случайный пароль.

.DESCRIPTION
    Скрипт получает список активных локальных пользователей (исключая системные),
    генерирует для каждого из них пароль заданной длины и сложности,
    и сохраняет результат в файл формата "имя<ТАБ>пароль".

.PARAMETER PathToFile
    Полный путь к файлу, в который будет сохранен список.

.PARAMETER PasswordLength
    (Необязательный) Длина генерируемых паролей. По умолчанию 12 символов.

.PARAMETER NoSpecialChars
    (Необязательный) Если указан этот ключ, пароли будут генерироваться
    БЕЗ специальных символов (только буквы и цифры).

.EXAMPLE
    # Пример 1: Сгенерировать пароли длиной 8 символов (со спецсимволами)
    .\Export-UsersForMigration.ps1 -PathToFile "C:\temp\users.txt" -PasswordLength 8

.EXAMPLE
    # Пример 2: Сгенерировать ПРОСТЫЕ пароли длиной 10 символов (БЕЗ спецсимволов)
    .\Export-UsersForMigration.ps1 -PathToFile "C:\temp\users.txt" -PasswordLength 10 -NoSpecialChars
#>
param(
    [Parameter(Mandatory=$true, HelpMessage="Укажите полный путь для сохранения файла.")]
    [string]$PathToFile,

    [Parameter(Mandatory=$false, HelpMessage="Длина генерируемых паролей.")]
    [int]$PasswordLength = 12,

    [Parameter(Mandatory=$false, HelpMessage="Генерировать пароли без специальных символов.")]
    [switch]$NoSpecialChars
)

# --- Новая, простая и надежная функция генерации паролей ---
function Generate-RandomPassword {
    param(
        [int]$length,
        [bool]$includeSpecialChars
    )
    # Определяем наборы символов
    $letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $numbers = "0123456789"
    $special = "!@#$%^&*-+=" # Уменьшил количество неоднозначных символов

    # Собираем общий набор символов в зависимости от флага
    $characterSet = $letters + $numbers
    if ($includeSpecialChars) {
        $characterSet += $special
    }
    
    # Конвертируем строку в массив символов для надежной работы Get-Random
    $charArray = $characterSet.ToCharArray()

    # Генерируем случайную последовательность нужной длины и объединяем в строку
    $password = -join ($charArray | Get-Random -Count $length)
    
    return $password
}
# --- Конец функции ---

Write-Host "Начинаю экспорт пользователей..." -ForegroundColor Cyan

# Список системных учетных записей для исключения
$systemAccounts = @("Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount", "defaultuser*")

try {
    $users = Get-LocalUser | Where-Object { $_.Enabled -eq $true }
    $outputLines = New-Object System.Collections.Generic.List[string]

    foreach ($user in $users) {
        if ($systemAccounts -contains $user.Name -or $user.Name -like "defaultuser*") {
            Write-Host "Пропускаю системного пользователя: $($user.Name)" -ForegroundColor Gray
            continue
        }

        # Генерируем пароль, передавая в функцию нужные параметры
        $newPassword = Generate-RandomPassword -length $PasswordLength -includeSpecialChars (-not $NoSpecialChars)
        
        $line = "$($user.Name)`t$newPassword"
        $outputLines.Add($line)

        Write-Host "Подготовлен пользователь: $($user.Name)" -ForegroundColor Green
    }

    if ($outputLines.Count -gt 0) {
        $outputLines | Out-File -FilePath $PathToFile -Encoding utf8
        Write-Host "`nУСПЕХ: Данные $($outputLines.Count) пользователей сохранены в файл: $PathToFile" -ForegroundColor Cyan
    } else {
        Write-Host "`nНе найдено пользователей для экспорта." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`nОШИБКА: Произошла ошибка во время выполнения скрипта." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
