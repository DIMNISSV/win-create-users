<#
.SYNOPSIS
    Создает локальных пользователей Windows из текстового файла.

.DESCRIPTION
    Скрипт читает текстовый файл, где каждая строка содержит имя пользователя и пароль, разделенные табуляцией.
    Он создает локальных пользователей с указанными данными и устанавливает требование смены пароля при первом входе.

.PARAMETER PathToFile
    Полный путь к текстовому файлу. Файл должен быть в формате: имя_пользователя<ТАБ>пароль.

.EXAMPLE
    .\Create-Users.ps1 -PathToFile "C:\temp\users.txt"
    Эта команда запустит скрипт и будет использовать файл users.txt для создания пользователей.
#>
param(
    [Parameter(Mandatory=$true, HelpMessage="Укажите полный путь к текстовому файлу с пользователями.")]
    [string]$PathToFile
)

# ===================================================================
#               Основная логика скрипта
# ===================================================================

# 1. Проверка, существует ли файл, указанный в аргументе
if (-not (Test-Path $PathToFile)) {
    Write-Host "Ошибка: Файл не найден по пути: '$PathToFile'" -ForegroundColor Red
    exit # Прекращаем выполнение, если файл не найден
}

Write-Host "Начинаю обработку файла: $PathToFile" -ForegroundColor Cyan

# 2. Чтение файла и создание пользователей
# Import-Csv используется с разделителем "табуляция" (`t)
# Заголовки "UserName" и "Password" присваиваются столбцам для удобства
$users = Import-Csv -Path $PathToFile -Delimiter "`t" -Header "UserName", "Password"

foreach ($user in $users) {
    # Пропускаем пустые строки в файле, если они есть
    if ([string]::IsNullOrWhiteSpace($user.UserName)) {
        continue
    }

    $username = $user.UserName
    $password = $user.Password

    # Проверяем, существует ли уже такой пользователь
    if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
        Write-Host "Пользователь '$username' уже существует. Пропускаем." -ForegroundColor Yellow
        continue # Переходим к следующему пользователю в списке
    }

    # Попытка создания пользователя в блоке try-catch для отлова ошибок
    try {
        # Пароль необходимо преобразовать в безопасную строку (SecureString)
        $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force

        # Создание нового локального пользователя
        New-LocalUser -Name $username -Password $securePassword -FullName $username -Description "Создан скриптом $(Get-Date)"

        # Устанавливаем флаг "Требовать смену пароля при следующем входе"
        $createdUser = Get-LocalUser -Name $username
        $createdUser.PasswordChangeable = $true
        $createdUser.PasswordRequired = $true
        $createdUser.Set()

        Write-Host "УСПЕХ: Пользователь '$username' успешно создан." -ForegroundColor Green
    }
    catch {
        # Вывод сообщения об ошибке, если что-то пошло не так
        # (например, пароль не соответствует политике сложности)
        Write-Host "ОШИБКА при создании пользователя '$username':" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

Write-Host "`nОбработка завершена." -ForegroundColor Cyan
