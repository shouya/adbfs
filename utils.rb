
ADB_PROGRAM = 'adb'
BUSYBOX = 'busybox'

def adb_exec(*command)
  full_cmd = [ADB_PROGRAM, 'shell']

  exec_cmd = BUSYBOX.dup
  exec_cmd << ' "'
  exec_cmd << command.join('" "')
  exec_cmd << '"; echo $?'

  full_cmd << exec_cmd

  puts "exec: #{full_cmd}"

  output = IO.popen(full_cmd).read

  status_code = output[/\d+\r\n$/].to_i
  output.sub!(/\d+\r\n$/, '')

  [status_code, output]
end
