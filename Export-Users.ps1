<#
.SYNOPSIS
    Экспортирует список локальных пользователей в текстовый файл,
    генерируя для каждого новый случайный пароль.

.DESCRIPTION
    Этот скрипт предназначен для подготовки к миграции пользователей. Он получает список
    всех активных локальных пользователей (исключая системные учетные записи),
    генерирует для каждого из них новый надежный пароль и сохраняет результат
    в файл формата "имя<ТАБ>пароль", готовый для использования скриптом Create-Users.ps1.

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

# Загружаем сборку System.Web для надежной генерации паролей
Add-Type -AssemblyName System.Web

Write-Host "Начинаю экспорт пользователей..." -ForegroundColor Cyan

# Список системных учетных записей, которые нужно исключить
$systemAccounts = @("Administrator", "Guest", "DefaultAccount", "WDAGUtilityAccount", "defaultuser*")

try {
    # Получаем всех локальных пользователей, которые активны (Enabled)
    $users = Get-LocalUser | Where-Object { $_.Enabled -eq $true }

    # Список для хранения строк "имя<ТАБ>пароль"
    $outputLines = New-Object System.Collections.Generic.List[string]

    foreach ($user in $users) {
        # Пропускаем системные учетные записи
        if ($systemAccounts -contains $user.Name -or $user.Name -like "defaultuser*") {
            Write-Host "Пропускаю системного пользователя: $($user.Name)" -ForegroundColor Gray
            continue
        }

        # Генерируем надежный пароль, содержащий как минимум 2 не-буквенно-цифровых символа
        $newPassword = [System.Web.Security.Membership]::GeneratePassword($PasswordLength, 2)
        
        # Формируем строку и добавляем в список
        $line = "$($user.Name)`t$newPassword"
        $outputLines.Add($line)

        Write-Host "Подготовлен пользователь: $($user.Name)" -ForegroundColor Green
    }

    # Сохраняем все строки в файл
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
