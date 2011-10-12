#!/usr/bin/env ruby
# kindle_clippings.rb -- Convert kindle clippings to text files
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2011-10-10.
# @Last Change: 2011-10-11.
# @Revision:    151

# require ''

require 'optparse'
require 'rbconfig'
require 'logger'
require 'yaml'

class KindleClippings
    APPNAME = 'kindle_clippings'
    VERSION = '0.0'
    CONFIGS = []
    if ENV['WINDIR']
        CONFIGS << File.join(File.dirname(ENV['WINDIR'].gsub(/\\/, '/')) ,'kindle_clippings.yml')
    else
        CONFIGS << '/etc/kindle_clippings.yml'
    end
    if ENV['HOME']
        CONFIGS << File.join(ENV['HOME'].gsub(/\\/, '/'), '.kindle_clippings.yml')
        if ENV['HOSTNAME']
            CONFIGS << File.join(ENV['HOME'].gsub(/\\/, '/'), ".kindle_clippings_#{ENV['HOSTNAME']}.yml")
        end
    elsif ENV['USERPROFILE']
        CONFIGS << File.join(ENV['USERPROFILE'].gsub(/\\/, '/'), 'kindle_clippings.yml')
    end
    CONFIGS.delete_if {|f| !File.exist?(f)}

    class AppLog
        def initialize(output=$stdout)
            @output = output
            $logger = Logger.new(output)
            $logger.progname = defined?(APPNAME) ? APPNAME : File.basename($0, '.*')
            $logger.datetime_format = "%H:%M:%S"
            AppLog.set_level
        end
    
        def self.set_level
            if $DEBUG
                $logger.level = Logger::DEBUG
            elsif $VERBOSE
                $logger.level = Logger::INFO
            else
                $logger.level = Logger::WARN
            end
        end
    end
    

    class << self
    
        def with_args(args)
    
            AppLog.new
    
            commands = KindleClippings.instance_methods.select {|m| m =~ /^cmd_/}.map {|m| m[4..-1]}
            formats = KindleClippings.instance_methods.select {|m| m =~ /^export_/}.map {|m| m[7..-1]}

            config = Hash.new
            config['outdir'] = Dir.pwd
            config['kindle_version'] = 2
            config['format'] = 'text'
            config['myclippings'] = 'My Clippings.txt'
            config['command'] = 'convert'
            CONFIGS.each do |file|
                begin
                    config.merge!(YAML.load_file(file))
                rescue TypeError
                    $logger.error "Error when reading configuration file: #{file}"
                end
            end
            opts = OptionParser.new do |opts|
                opts.banner =  "Usage: #{File.basename($0)} [OPTIONS] [My\\ Clippings.txt]"
                opts.separator ' '
                opts.separator 'kindle_clippings is a free software with ABSOLUTELY NO WARRANTY under'
                opts.separator 'the terms of the GNU General Public License version 2 or newer.'
                opts.separator ' '
            
                opts.separator 'General Options:'
                opts.on('-c', '--command COMMAND', commands, "Execute a command: #{commands.join(", ")} (default: #{config['command']})") do |value|
                    config['command'] = value
                end

                opts.on('-d DIR', '--dir DIR', String, 'Output directory (default: current directory)') do |value|
                    config['outdir'] = value
                end

                opts.on('--format FORMAT,...', String, "Export format: #{formats.join(", ")} (default: #{config["format"]})") do |value|
                    config['format'] = value
                end
                
                opts.on('-k VERSION', '--kindle VERSION', Integer, 'Kindle version (default: 2)') do |value|
                    config['kindle_version'] = value
                end
                
                opts.on('--print-config', 'Print the configuration and exit') do |bool|
                    puts "Configuration files: #{CONFIGS}"
                    puts YAML.dump(config)
                    exit
                end
                
                unless CONFIGS.empty?
                    opts.separator ' '
                    opts.separator "Configuration: #{CONFIGS.join(', ')}"
                end
                
                opts.separator ' '
                opts.separator 'Other Options:'
            
                opts.on('--debug', 'Show debug messages') do |v|
                    $DEBUG   = true
                    $VERBOSE = true
                    AppLog.set_level
                end
            
                opts.on('-v', '--verbose', 'Run verbosely') do |v|
                    $VERBOSE = true
                    AppLog.set_level
                end
            
                opts.on_tail('-h', '--help', 'Show this message') do
                    puts opts
                    exit 1
                end
            end
            $logger.debug "command-line arguments: #{args}"
            argv = opts.parse!(args)
            $logger.debug "config: #{config}"
            $logger.debug "argv: #{argv}"
            if argv.count == 1
                config['myclippings'] = argv[0]
            elsif argv.count > 1
                $logger.fatal "Must supply at most one argument: path to 'My Clippings.txt': #{argv.inspect}/#{argv.count}"
                exit 5
            end
            if !File.exist?(config['myclippings'])
                $logger.fatal "Could not find 'My Clippings.txt': #{config['myclippings']}"
                exit 5
            end
    
            return KindleClippings.new(config, argv)
    
        end
    
    end

    # config ... hash
    # args   ... array of strings
    def initialize(config, args)
        @config = config
        @args   = args
    end

    def process
        m = "cmd_#{@config['command']}"
        if respond_to?(m)
            send(m)
        else
            $logger.fatal "Unknown command: #{@config['command']}"
        end
    end

    def cmd_list
        my_clippings = import
        unless my_clippings.empty?
            puts my_clippings.keys.join("\n")
        end
    end

    def cmd_convert
        my_clippings = import
        unless my_clippings.empty?
            @config['format'].split(/,/).each do |format|
                method = "export_#{format}"
                if respond_to?(method)
                    send(method, my_clippings)
                else
                    $logger.fatal "Unsupported export format: #{format}"
                end
            end
        end
    end

    def help_convert
        <<HELP
Convert your kindle klippings.

Example usage:
#{APPNAME} --dir ~/MyClips /media/kindle/My\\ Clippings.txt
HELP
    end

    def import
        case @config['kindle_version']
        when 2
            import2
        else
            $logger.fatal "Unsupported kindle version: #{@config['kindle_version']}"
            exit 5
        end
    end

    def import2
        mode = nil
        lnum = 0
        my_clippings = {}
        skip = false
        loc = nil
        lines = {}
        title = ""
        File.open(@config['myclippings']).each_line do |line|
            line = (lnum == 0 ? line[3..-1] : line)
            line.chomp!
            if skip
                $logger.debug "Skip: #{lnum}: #{line}" unless line.empty?
                skip = false
            else
                $logger.debug "Mode #{mode}: #{lnum}: #{line}"
                case mode
                when nil
                    loc = nil
                    lines = {}
                    title = line
                    my_clippings[title] ||= {}
                    mode = :select
                    $logger.debug "Title: #{title}"
                when :select
                    if line =~ /^- Highlight Loc\. (\d+)/
                        loc = $1.to_i
                        mode = :clip
                        skip = true
                    elsif line =~ /^- Note Loc\. (\d+)/
                        loc = $1.to_i
                        mode = :note
                        skip = true
                    elsif line =~ /^- Bookmark Loc\. (\d+)/
                        loc = $1.to_i
                        mode = :bookmark
                        skip = true
                    else
                        $logger.warn "Unsupported entry type: #{line}"
                    end
                    $logger.debug "Set mode = #{mode} @ #{loc}"
                when :clip
                    if line == '=========='
                        mode = nil
                        $logger.debug "Clip: Merge lines: #{lines}"
                        my_clippings[title].merge!(lines) do |k, o, n|
                            o + n
                        end
                    else
                        $logger.debug "Save line: #{loc}: #{line}"
                        lines[loc] = [line]
                    end
                when :note
                    if line == '=========='
                        mode = nil
                        $logger.debug "Note: Merge lines: #{lines}"
                        my_clippings[title].merge!(lines) do |k, o, n|
                            o + n
                        end
                    else
                        $logger.debug "Save line: #{loc}: #{line}"
                        lines[loc] = ["NOTE: #{line}"]
                    end
                when :bookmark
                    if line == '=========='
                        mode = nil
                    else
                    end
                else
                    $logger.error "Internal error: Unsupported mode: #{mode}"
                    mode = nil
                end
            end
            lnum += 1
        end
        return my_clippings
    end

    def export_text(my_clippings)
        prefix = " " * 60
        Dir.chdir(@config['outdir']) do
            my_clippings.each do |title, data|
                ctitle = "#{title.gsub(/[[:cntrl:].+*:"?<>|&\\\/%]/, '_')}.txt"
                text = data.keys.sort.map {|loc| "#{prefix}##{loc}\n#{data[loc].join("\n\n")}\n\n"}
                unless text.empty?
                    File.open(ctitle, 'w') do |io|
                        io.puts(title)
                        io.puts
                        io.puts(text)
                    end
                end
            end
        end
    end

    def export_viki(my_clippings)
        Dir.chdir(@config['outdir']) do
            my_clippings.each do |title, data|
                ctitle = "#{title.gsub(/[[:cntrl:].+*:"?<>|&\\\/%]/, '_')}.txt"
                rx_author = /\([^)]+\)$/
                tauthor = title[rx_author].gsub(/(^\(|\)$)/, '')
                ttitle = title.sub(rx_author, '')
                text = data.keys.sort.map {|loc| "##{loc}\n#{data[loc].join("\n\n")}\n\n"}
                unless text.empty?
                    File.open(ctitle, 'w') do |io|
                        io.puts("#TITLE: #{ttitle}")
                        io.puts("#AUTHOR: #{tauthor}\n\n")
                        io.puts(text)
                        io.puts("\n% vi: ft=viki:tw=0")
                    end
                end
            end
        end
    end

end


if __FILE__ == $0
    KindleClippings.with_args(ARGV).process
end


