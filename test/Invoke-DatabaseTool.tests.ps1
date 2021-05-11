
# Describe 'Invoke-DatabaseTool' {

#     BeforeAll {
#         $scriptPath = "$PSScriptRoot\..\Invoke-DatabaseTool.ps1"
#         $logPath = "$env:TEMP\Pester-$((New-Guid).Guid).txt"

#         $scriptParams = @{
#             ToolPath     = 'C:\Windows\System32\cmd.exe'
#             ArgumentList = '/?'
#             LogPath      = $logPath
#         }

#         $result = & $scriptPath @scriptParams
#     }

#     It 'Runs without failures' {
#         $result | Should -Not Throw
#     }

#     AfterAll {
#         Remove-Item $logPath -Force
#     }
# }
