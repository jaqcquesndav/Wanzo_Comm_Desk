# Test ADHA API Endpoint
# Usage: .\test_adha_api.ps1

$token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjRlQUJzRldHVC1yTnZCeTVjTGNLWiJ9.eyJodHRwczovL3dhbnpvLmNvbS9yb2xlcyI6WyJhZG1pbiJdLCJodHRwczovL3dhbnpvLmNvbS9yb2xlIjoiYWRtaW4iLCJpc3MiOiJodHRwczovL2Rldi10ZXptbG4wdGswZzFnb3VmLmV1LmF1dGgwLmNvbS8iLCJzdWIiOiJnb29nbGUtb2F1dGgyfDExMzUzMTY4NjEyMTI2NzA3MDQ4OSIsImF1ZCI6WyJodHRwczovL2FwaS53YW56by5jb20iLCJodHRwczovL2Rldi10ZXptbG4wdGswZzFnb3VmLmV1LmF1dGgwLmNvbS91c2VyaW5mbyJdLCJpYXQiOjE3NjkwOTk4NDAsImV4cCI6MTc2OTE4NjI0MCwic2NvcGUiOiJvcGVuaWQgcHJvZmlsZSBlbWFpbCBvZmZsaW5lX2FjY2VzcyIsImF6cCI6IlBJdWtKQkxmRndRSTdzbGVjWGFWRUQ2MWI3eWE4SVBDIiwicGVybWlzc2lvbnMiOlsiYWNjb3VudGluZzpyZWFkIiwiYWNjb3VudGluZzp3cml0ZSIsImFkbWluOmZ1bGwiLCJhbmFseXRpY3M6cmVhZCIsImFuYWx5dGljczp3cml0ZSIsImluc3RpdHV0aW9uOm1hbmFnZSIsIm1vYmlsZTpyZWFkIiwibW9iaWxlOndyaXRlIiwicG9ydGZvbGlvOnJlYWQiLCJwb3J0Zm9saW86d3JpdGUiLCJzZXR0aW5nczptYW5hZ2UiLCJ1c2VyczptYW5hZ2UiXX0.rJeD5W9sBEfS8bsIqtmsSLYWpq_dNil49zI32Eye4mxefHQmhi639ghATDsaMPltqQPo1HYHEb1umWLNK4Gj-O_O1fuUUbrFgz0hcpfGLsv6xcL1irbmXQoOBPBad71h-Nj9g-NIqcZdHn3l1Hi2J92lyOiaKd5AjQAypwShC0C2XuITx0bMrw1Pi2KypWq-Bv71gVhWvIbOyJ6NG1IgcOojGxqCO5HwVxyHVrob_oTzMJy4UuQXkR88JEO6y_VMXHPKE0hkKdexjvygOpz_sjBNUdPLEmuVMwPAVTFVany4lTNx0RxrcIijCgxGhQgIBREGEX_jENDFkKGlXfaH1w"

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$body = @{
    text = "Bonjour, quel est mon chiffre d'affaires?"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    companyId = "d0a01bbb-6b28-402c-8ba0-b324bfd85526"
    userId = "807b15e7-bb5a-462d-b2df-2bd566378f1c"
    contextInfo = @{
        baseContext = @{
            operationJournalSummary = @{
                totalSales = 0
                totalPurchases = 0
                totalExpenses = 0
            }
            businessProfile = @{
                businessName = "Test Business"
                businessType = "retail"
            }
        }
        interactionContext = @{
            interactionType = "generic_card_analysis"
        }
    }
} | ConvertTo-Json -Depth 10

Write-Host "===== ADHA API TEST =====" -ForegroundColor Cyan
Write-Host "URL: http://localhost:8000/commerce/api/v1/adha/message"
Write-Host "Body:" -ForegroundColor Yellow
Write-Host $body
Write-Host ""
Write-Host "Sending request (timeout 120s)..." -ForegroundColor Green

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8000/commerce/api/v1/adha/message" `
        -Method POST `
        -Headers $headers `
        -Body $body `
        -TimeoutSec 120 `
        -UseBasicParsing

    Write-Host ""
    Write-Host "===== SUCCESS =====" -ForegroundColor Green
    Write-Host "Status: $($response.StatusCode)"
    Write-Host "Response:" -ForegroundColor Yellow
    $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
} catch {
    Write-Host ""
    Write-Host "===== ERROR =====" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)"
    
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
        Write-Host "Status Code: $statusCode"
        
        try {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Response Body:" -ForegroundColor Yellow
            Write-Host $errorBody
        } catch {
            Write-Host "Could not read response body"
        }
    }
}
