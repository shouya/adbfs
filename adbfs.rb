
require 'ap'

require 'fusefs'

require_relative 'utils'

class ADBFS < FuseFS::FuseDir
  attr_accessor :buffer

  def initialize
    @buffer = {}
  end

  def contents(path)
    status, out = adb_exec('ls', '-A1F', '--color=never', '--', path)
    if status != 0
      return false
    end

    content = out.each_line.map(&:chomp).to_a

    @buffer[:cwd] = {
      :path => path,
      :files => content.grep(/[^\/\@\*\|\=\>]$/),
      :others => content.grep(/[\@\*\|\=\>]$/),
      :dirs => content.grep(/\/$/).map {|x| x[0..-2]}
    }
    ap @buffer

    content.map {|x| x.sub(/[\/\@\*\|\=\>]?$/, '') }
  end

  def file?(path)
    record_file = false
    if path.start_with? @buffer[:cwd][:path]
      filename = path.sub(@buffer[:cwd][:path], '')
      puts "test file: #{path}"
      unless filename.include? '/'
        return true if @buffer[:cwd][:files].include? filename
        return false if @buffer[:cwd][:files].include? filename
        if @buffer[:cwd][:others].include? "#{filename}*" or
            @buffer[:cwd][:others].include? "#{filename}@"
          puts "falling file: #{path}"
          record_file = filename
        else
          return false
        end
      end
    end
    
    puts "testing file #{path}"
    
    status, out = adb_exec('ls', '-A1F', '--', path)
    
    if status == 0
      return false if out.each_line.count != 1
      @buffer[:cwd][:files] << record_file if record_file
      return true
    else
      false
    end
  end

  def directory?(path)
    record_dir = false
    if path.start_with? @buffer[:cwd][:path]
      filename = path.sub(@buffer[:cwd][:path], '')
      unless filename.include? '/'
        puts "test dir: #{path}"
        return true if @buffer[:cwd][:dirs].include? filename

        if @buffer[:cwd][:others].include? "#{filename}*" or
            @buffer[:cwd][:others].include? "#{filename}@"
          puts "falling back: #{path}"
          record_dir = filename
        else
          return false
        end
      end
    end

    puts "testing dir #{path}"

    status, out = adb_exec('ls', '-A1F', '--', path)

    if status == 0
      return false if out.each_line.count == 1
      @buffer[:cwd][:dirs] << record_dir if record_dir
      return true
    else
      false
    end
  end

  def read_file(path)
    status, out = adb_exec('cat', path)

    if status.to_i != 0
      return false
    end

    out
  end
end

adbfs = ADBFS.new
FuseFS.set_root(adbfs)


trap :INT do
  system('sudo', 'umount', FuseFS.instance_variable_get(:@mountpoint))
  exit
end

FuseFS.mount_under ARGV.shift
FuseFS.run
