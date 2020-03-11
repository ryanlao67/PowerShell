$table = `
	@{Expression={$_.Name};Label="Executable";width=20}, `
	@{Expression={$_.Description};Label="Process Description";width=25}, `
	@{Expression={$_.ID};Label="PID";width=7;align="left"}, `
	@{Expression={"{0:N1}" -f ($_.CPU)};Label="CPU Load";width=10;align="left"}, `
	@{Expression={"{0:N0}" -f ($_.NPM / 1024)};Label="Nonpaged (MB)";width=15;align="left"}, `
	@{Expression={"{0:N0}" -f ($_.PM / 1024)};Label="Paged (MB)";width=15;align="left"}, `
	@{Expression={"{0:N0}" -f ($_.WS / 1024)};Label="Working (MB)";width=15;align="left"}, `
	@{Expression={"{0:N0}" -f ($_.VM / 1024)};Label="Virtual (MB)";width=15;align="left"}

Get-Process | Sort-Object CPU -Descending | ft $table