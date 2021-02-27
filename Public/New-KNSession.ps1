<#
.SYNOPSIS
    Authentificate on Keenetic device and save session parameters.
.DESCRIPTION
    Process auth challenge on given device and output result for use in future.
    Please note about session expiration after few minutes of inactivity.
.EXAMPLE
    PS C:\> New-KNSession -Target https://my.keenetic.com -Credential (Get-Credential) -AsDefaultSession
    Log onto Keenetic Router on given URL using given credentials and save session parameters in memory for further use.
.EXAMPLE
    PS C:\> New-KNSession -Credential (Get-Credential)
    Log onto Keenetic Router on default address 'http://my.keenetic.net' and return session parameters as an object.
.INPUTS
    Inputs (if any)
.OUTPUTS
    Session parameters, including System.Net.CookieContainer to further web requests.
.NOTES
    General notes
.LINK
    https://github.com/ryzhovau/keenetic-powershell
#>
function New-KNSession {
    [CmdletBinding()]
    param(
        [string]$Target='http://my.keenetic.net',
        [pscredential]$Credential,
        [Switch]$AsDefaultSession
    )
    Begin {
        function Get-Hash (
        [string]$String, 
        [string]$Algo)
        {
            $HashEngine=[System.Security.Cryptography.HashAlgorithm]::create($algo)
            $UTF8=New-Object -TypeName System.Text.UTF8Encoding
            [System.BitConverter]::ToString($HashEngine.ComputeHash($utf8.GetBytes($String))).ToLower().Replace('-', '')
        }
    }
    Process {
        try {
            # First, we should catch X-NDM-Challenge/X-NDM-Realm headers from 401 response
            Invoke-WebRequest -Uri "$Target/auth" -SessionVariable WebSession | Out-Null
        } catch  [System.Net.WebException] {
            $Response=$_.Exception.Response
            If ($Response.StatusCode -ne 'Unauthorized') {
                throw [System.Net.WebException] "Unexpected status received.`n$($_.Exception)"  
            }
            <# Challenge is to send POST request with following data
            {  
                login: login,
                password: sha256(token + md5(login + ':' + realm + ':' + password))
            } #>
            $Token=$Response.Headers["X-NDM-Challenge"]
            $Realm=$Response.Headers["X-NDM-Realm"]
            Write-Verbose "X-NDM-Challenge header is $($Token)"
            Write-Verbose "X-NDM-Realm header is $($Realm)"
            $MD5Hash=Get-Hash "$($Credential.GetNetworkCredential().UserName):$($Realm):$($Credential.GetNetworkCredential().Password)" 'MD5'
            $SHA256Hash=Get-Hash "$($Token)$($MD5Hash)" 'SHA256'
            $PostBody=@{"login"=$Credential.GetNetworkCredential().UserName; "password"=$SHA256Hash} | ConvertTo-Json
            Write-Verbose "Challenge request body is:`n$($PostBody)"
            try {
                Invoke-WebRequest -Uri "$Target/auth" -WebSession $WebSession -Method Post -Body $PostBody -ContentType 'application/json' | Out-Null
            } catch {
                throw [System.Net.WebException] "Logon failed.`n$($_.Exception)"
            }
            return [PSCustomObject]@{ 
                Target=$Target
                Credential=$Credential
                WebSession=$WebSession
            }
        }
    }
    End {
    }
}
