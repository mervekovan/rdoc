require 'optparse'

require 'rdoc/ri/paths'

##
# RDoc::Options handles the parsing and storage of options

class RDoc::Options

  ##
  # The deprecated options.

  DEPRECATED = {
    '--accessor'      => 'support discontinued',
    '--diagram'       => 'support discontinued',
    '--help-output'   => 'support discontinued',
    '--image-format'  => 'was an option for --diagram',
    '--inline-source' => 'source code is now always inlined',
    '--merge'         => 'ri now always merges class information',
    '--one-file'      => 'support discontinued',
    '--op-name'       => 'support discontinued',
    '--opname'        => 'support discontinued',
    '--promiscuous'   => 'files always only document their content',
    '--ri-system'     =>  'Ruby installers use other techniques',
  }

  ##
  # If true, RDoc will not write any files.

  attr_accessor :dry_run

  ##
  # Encoding of output where.  This is set via --encoding.

  attr_accessor :encoding if Object.const_defined? :Encoding

  ##
  # Files matching this pattern will be excluded

  attr_accessor :exclude

  ##
  # The list of files to be processed

  attr_accessor :files

  ##
  # Create the output even if the output directory does not look
  # like an rdoc output directory

  attr_accessor :force_output

  ##
  # Scan newer sources than the flag file if true.

  attr_accessor :force_update

  ##
  # Formatter to mark up text with

  attr_accessor :formatter

  ##
  # Description of the output generator (set with the <tt>-fmt</tt> option)

  attr_accessor :generator

  ##
  # The name of the output directory

  attr_accessor :op_dir

  ##
  # The OptionParser for this instance

  attr_accessor :option_parser

  ##
  # Is RDoc in pipe mode?

  attr_accessor :pipe

  ##
  # Array of directories to search for files to satisfy an :include:

  attr_accessor :rdoc_include

  ##
  # The number of columns in a tab

  attr_accessor :tab_width

  ##
  # Verbosity, zero means quiet

  attr_accessor :verbosity

  ##
  # Minimum visibility of a documented method. One of +:public+,
  # +:protected+, +:private+. May be overridden on a per-method
  # basis with the :doc: directive.

  attr_accessor :visibility

  def initialize # :nodoc:
    require 'rdoc/rdoc'
    @dry_run = false
    @exclude = []
    @force_output = false
    @force_update = true
    @generator = nil
    @generator_name = nil
    @generator_options = []
    @generators = RDoc::RDoc::GENERATORS
    @hyperlink_all = false
    @line_numbers = false
    @main_page = nil
    @op_dir = nil
    @pipe = false
    @rdoc_include = []
    @show_hash = false
    @stylesheet_url = nil
    @tab_width = 8
    @template = nil
    @title = nil
    @verbosity = 1
    @visibility = :protected
    @webcvs = nil

    if Object.const_defined? :Encoding then
      @encoding = Encoding.default_external
      @charset = @encoding.to_s
    else
      @charset = 'UTF-8'
    end
  end

  ##
  # Parse command line options.

  def parse(argv)
    ignore_invalid = true

    argv.insert(0, *ENV['RDOCOPT'].split) if ENV['RDOCOPT']

    opts = OptionParser.new do |opt|
      @option_parser = opt
      opt.program_name = File.basename $0
      opt.version = RDoc::VERSION
      opt.release = nil
      opt.summary_indent = ' ' * 4
      opt.banner = <<-EOF
Usage: #{opt.program_name} [options] [names...]

  Files are parsed, and the information they contain collected, before any
  output is produced. This allows cross references between all files to be
  resolved. If a name is a directory, it is traversed. If no names are
  specified, all Ruby files in the current directory (and subdirectories) are
  processed.

  How RDoc generates output depends on the output formatter being used, and on
  the options you give.

  Options can be specified via the RDOCOPT environment variable, which
  functions similar to the RUBYOPT environment variable for ruby.
  
    $ export RDOCOPT="--show-hash"
  
  will make rdoc show hashes in method links by default.  Command-line options
  always will override those in RDOCOPT.

  - Darkfish creates frameless HTML output by Michael Granger.
  - ri creates ri data files

  RDoc understands the following file formats:

      EOF

      parsers = Hash.new { |h,parser| h[parser] = [] }

      RDoc::Parser.parsers.each do |regexp, parser|
        parsers[parser.name.sub('RDoc::Parser::', '')] << regexp.source
      end

      parsers.sort.each do |parser, regexp|
        opt.banner << "  - #{parser}: #{regexp.join ', '}\n"
      end

      opt.banner << "\n  The following options are deprecated:\n\n"

      name_length = DEPRECATED.keys.sort_by { |k| k.length }.last.length

      DEPRECATED.sort_by { |k,| k }.each do |name, reason|
        opt.banner << "    %*1$2$s  %3$s\n" % [-name_length, name, reason]
      end

      opt.separator nil
      opt.separator "Parsing options:"
      opt.separator nil

      if Object.const_defined? :Encoding then
        opt.on("--encoding=ENCODING", "-e", Encoding.list.map { |e| e.name },
               "Specifies the output encoding.  All files",
               "read will be converted to this encoding.",
               "Preferred over --charset") do |value|
                 @encoding = Encoding.find value
                 @charset = @encoding.to_s # may not be valid value
               end

        opt.separator nil
      end

      opt.on("--all", "-a",
             "Synonym for --visibility=private.") do |value|
        @visibility = :private
      end

      opt.separator nil

      opt.on("--exclude=PATTERN", "-x", Regexp,
             "Do not process files or directories",
             "matching PATTERN.") do |value|
        @exclude << value
      end

      opt.separator nil

      opt.on("--extension=NEW=OLD", "-E",
             "Treat files ending with .new as if they",
             "ended with .old. Using '-E cgi=rb' will",
             "cause xxx.cgi to be parsed as a Ruby file.") do |value|
        new, old = value.split(/=/, 2)

        unless new and old then
          raise OptionParser::InvalidArgument, "Invalid parameter to '-E'"
        end

        unless RDoc::Parser.alias_extension old, new then
          raise OptionParser::InvalidArgument, "Unknown extension .#{old} to -E"
        end
      end

      opt.separator nil

      opt.on("--[no-]force-update", "-U",
             "Forces rdoc to scan all sources even if",
             "newer than the flag file.") do |value|
        @force_update = value
      end

      opt.separator nil

      opt.on("--pipe",
             "Convert RDoc on stdin to HTML") do
        @pipe = true
      end

      opt.separator nil

      opt.on("--tab-width=WIDTH", "-w", OptionParser::DecimalInteger,
             "Set the width of tab characters.") do |value|
        @tab_width = value
      end

      opt.separator nil

      opt.on("--visibility=VISIBILITY", "-V", RDoc::VISIBILITIES,
             "Minimum visibility to document a method.",
             "One of 'public', 'protected' (the default)",
             "or 'private'. Can be abbreviated.") do |value|
        @visibility = value
      end

      opt.separator nil
      opt.separator "Common generator options:"
      opt.separator nil

      opt.on("--force-output", "-O",
             "Forces rdoc to write the output files,",
             "even if the output directory exists",
             "and does not seem to have been created",
             "by rdoc.") do |value|
        @force_output = value
      end

      opt.separator nil

      generator_text = @generators.keys.map { |name| "  #{name}" }.sort

      opt.on("-f", "--fmt=FORMAT", "--format=FORMAT", @generators.keys,
             "Set the output formatter.  One of:", *generator_text) do |value|
        if @generator then
          raise OptionParser::InvalidOption,
                "generator already set to #{@generator_name}"
        end

        @generator_name = value.downcase
        setup_generator
      end

      opt.separator nil

      opt.on("--include=DIRECTORIES", "-i", Array,
             "Set (or add to) the list of directories to",
             "be searched when satisfying :include:",
             "requests. Can be used more than once.") do |value|
        @rdoc_include.concat value.map { |dir| dir.strip }
      end

      opt.separator nil

      opt.on("--output=DIR", "--op", "-o",
             "Set the output directory.") do |value|
        @op_dir = value
      end

      opt.separator nil

      opt.on("-d",
             "Deprecated --diagram option.",
             "Prevents firing debug mode",
             "with legacy invocation.") do |value|
      end

      opt.separator nil
      opt.separator "ri generator options:"
      opt.separator nil

      opt.on("--ri", "-r",
             "Generate output for use by `ri`. The files",
             "are stored in the '.rdoc' directory under",
             "your home directory unless overridden by a",
             "subsequent --op parameter, so no special",
             "privileges are needed.") do |value|
        if @generator then
          raise OptionParser::InvalidOption,
                "generator already set to #{@generator_name}"
        end

        @generator_name = "ri"
        @op_dir ||= RDoc::RI::Paths::HOMEDIR
        setup_generator
      end

      opt.separator nil

      opt.on("--ri-site", "-R",
             "Generate output for use by `ri`. The files",
             "are stored in a site-wide directory,",
             "making them accessible to others, so",
             "special privileges are needed.") do |value|
        if @generator then
          raise OptionParser::InvalidOption,
                "generator already set to #{@generator_name}"
        end

        @generator_name = "ri"
        @op_dir = RDoc::RI::Paths::SITEDIR
        setup_generator
      end

      opt.separator nil
      opt.separator "Generic options:"
      opt.separator nil

      opt.on("--[no-]dry-run",
             "Don't write any files") do |value|
        @dry_run = value
      end

      opt.on("-D", "--[no-]debug",
             "Displays lots on internal stuff.") do |value|
        $DEBUG_RDOC = value
      end

      opt.on("--[no-]ignore-invalid",
             "Ignore invalid options and continue",
             "(default true).") do |value|
        ignore_invalid = value
      end

      opt.on("--quiet", "-q",
             "Don't show progress as we parse.") do |value|
        @verbosity = 0
      end

      opt.on("--verbose", "-v",
             "Display extra progress as RDoc parses") do |value|
        @verbosity = 2
      end

      opt.on("--help",
             "Display this help") do
        RDoc::RDoc::GENERATORS.each_key do |generator|
          setup_generator generator
        end

        puts opt.help
        exit
      end

      opt.separator nil
    end

    setup_generator 'darkfish' if
    argv.grep(/\A(-f|--fmt|--format|-r|-R|--ri|--ri-site)\b/).empty?

    deprecated = []
    invalid = []

    begin
      opts.parse! argv
    rescue OptionParser::InvalidArgument, OptionParser::InvalidOption => e
      if DEPRECATED[e.args.first] then
        deprecated << e.args.first
      elsif %w[--format --ri -r --ri-site -R].include? e.args.first then
        raise
      else
        invalid << e.args.join(' ')
      end
      retry
    end

    @generator ||= RDoc::Generator::Darkfish

    if @pipe and not argv.empty? then
      @pipe = false
      invalid << '-p (with files)'
    end

    unless quiet then
      deprecated.each do |opt|
        $stderr.puts 'option ' << opt << ' is deprecated: ' << DEPRECATED[opt]
      end

      unless invalid.empty? then
        invalid = "invalid options: #{invalid.join ', '}"

        if ignore_invalid then
          $stderr.puts invalid
          $stderr.puts '(invalid options are ignored)'
        else
          $stderr.puts opts
          $stderr.puts invalid
          exit 1
        end
      end
    end

    @op_dir ||= 'doc'
    @files = argv.dup

    @rdoc_include << "." if @rdoc_include.empty?

    if @exclude.empty? then
      @exclude = nil
    else
      @exclude = Regexp.new(@exclude.join("|"))
    end

    check_files

    # If no template was specified, use the default template for the output
    # formatter

    @template ||= @generator_name
  end

  ##
  # Set the title, but only if not already set. This means that a title set
  # from the command line trumps one set in a source file

  def title=(string)
    @title ||= string
  end

  ##
  # Don't display progress as we process the files

  def quiet
    @verbosity.zero?
  end

  def quiet=(bool)
    @verbosity = bool ? 0 : 1
  end

  private

  ##
  # Set up an output generator for the named +generator_name+.
  #
  # If the found generator responds to :setup_options it will be called with
  # the options instance.  This allows generators to add custom options or set
  # default options.

  def setup_generator generator_name = @generator_name
    @generator = @generators[generator_name]

    unless @generator then
      raise OptionParser::InvalidArgument,
            "Invalid output formatter #{generator_name}"
    end

    return if @generator_options.include? @generator

    @generator_options << @generator

    @generator.setup_options self if @generator.respond_to? :setup_options
  end

  ##
  # Check that the files on the command line exist

  def check_files
    @files.each do |f|
      raise RDoc::Error, "file '#{f}' not found" unless File.exist?(f)
      stat = File.stat f
      raise RDoc::Error, "file '#{f}' not readable" unless stat.readable?
    end
  end

end

