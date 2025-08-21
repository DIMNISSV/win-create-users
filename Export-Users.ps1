<#
.SYNOPSIS
    Экспортирует список локальных пользователей в текстовый файл,
    генерируя для каждого новый случайный пароль.

.DESCRIPTION
    Этот скрипт предназначен для подготовки к миграции пользователей. Он получает список
    всех активных локальных пользователей (исключая системные), генерирует для каждого
    новый надежный пароль и сохраняет результат в файл формата "имя<ТАБ>пароль".
    Работает в любой версии PowerShell.

.PARAMETER PathToFile
    Полный путь к файлу, в который будет сохранен список пользователей.

.PARAMETER PasswordLength
    (Необязательный) Длина генерируемых паролей. По умолчанию 16 символов.

.EXAMPLE
    .\Export-UsersForMigration.ps1 -PathToFile "C:\temp\users_to_migrate.txt"

.EXAMPLE
    .\Export-UsersForMigration.ps1 -PathToFile "C:\temp\users_to_migrate.txt" -PasswordLength 20
#>
param(
    [Parameter(Mandatory=$true, HelpMessage="Укажите полный путь для сохранения файла.")]
    [string]$PathToFile,

    [Parameter(Mandatory=$false, HelpMessage="Длина генерируемых паролей.")]
    [int]$PasswordLength = 16
)

# --- Встроенная функция для генерации паролей (работает везде) ---
function Generate-RandomPassword {
    param(
        [int]$length = 16
    )
    # Определяем наборы символов
    $lowerCase = 'abcdefghijklmnopqrstuvwxyz'
    $upperCase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $numbers = '0123456789'
    $specialChars = '!@#$%^&*()-_=+'

    # Гарантируем, что в пароле будет хотя бы по одному символу каждого типа
    $passwordChars = @()
    $passwordChars += $lowerCase | Get-Random -Count 1
    $passwordChars += $upperCase | Get-Random -Count 1
    $passwordChars += $numbers | Get-Random -Count 1
    $passwordChars += $specialChars | Get-Random -Count 1

    # Заполняем оставшуюся длину случайными символами из всех наборов
    $allChars = $lowerCase + $upperCase + $numbers + $specialChars
    $remainingLength = $length - $passwordChars.Count
    if ($remainingLength -gt 0) {
        $passwordChars += $allChars | Get-Random -Count $remainingLength
    }

    # Перемешиваем символы, чтобы они не шли в предсказуемом порядке, и объединяем в строку
    $finalPassword = ($passwordChars | Get-Random -Count $passwordChars.Count) -join ''
    return $finalPassword
}
# --- Конец функции ---

Write-Host "Начинаю экспорт пользователей..." -ForegroundColor Cyan

# Список системных учетных записей, которые нужно исключить
$systemAccounts = @("Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount", "defaultuser*")

try {
    # Получаем всех активных локальных пользователей
    $users = Get-LocalUser | Where-Object { $_.Enabled -eq $true }

    $outputLines = New-Object System.Collections.Generic.List[string]

    foreach ($user in $users) {
        # Пропускаем системные учетные записи
        if ($systemAccounts -contains $user.Name -or $user.Name -like "defaultuser*") {
            Write-Host "Пропускаю системного пользователя: $($user.Name)" -ForegroundColor Gray
            continue
        }

        # Генерируем пароль с помощью нашей новой функции
        $newPassword = Generate-RandomPassword -length $PasswordLength
        
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
