class Serpent::Input::Parser::WordScanner
  attr_reader :words

  def initialize text
    @text = text
  end

  def parse
    reset_parser
    until eof?
      case curr_char
        when '"'
          start_word and add_chars_until? '"'
          close_word
        when '#','%'
          start_word and add_chars_until? "\n"
          close_word
        when '/'
          if next_is? '*' then
            start_word and 2.times { add_char }
            add_char until curr_is? '*' and next_is? '/' or eof?
            2.times { add_char } unless eof?
            close_word
          else
            # parser_error "unexpected symbol '/'" # if not allowed in the grammar
            start_word unless word_already_started?
            add_char
          end
        when /[^\s]/
          start_word unless word_already_started?
          add_char
      else # skip whitespaces etc. between words
        move and close_word
      end
    end
    return @words
  end

private

  def reset_parser
    @position = 0
    @line, @column = 1, 1
    @words = []
    @word_started = false
  end

  def parser_error s
    Kernel.puts 'Parser error on line %d, col %d: ' + s
    raise 'Parser error'
  end

  def word_already_started?
    @word_started
  end

  def close_word
    @word_started = false
  end

  def add_chars_until? ch
    add_char until next_is? ch or eof?
    2.times { add_char } unless eof?
  end

  def add_char
    @words.last[:to] = @position
    # @words.last[:length] += 1
    # @word.last += curr_char # if one just collects words
    move
  end

  def start_word
    @words.push from: @position, to: @position, line: @line, column: @column
    # @words.push '' unless @words.last.empty? # if one just collects words
    @word_started = true
  end

  def move
    increase :@position
    return if eof?
    if prev_is? "\n"
      increase :@line
      reset :@column
    else
      increase :@column
    end
  end

  def reset var; instance_variable_set(var, 1) end
  def increase var; instance_variable_set(var, instance_variable_get(var)+1) end

  def eof?; @position >= @text.length end

  def prev_is? ch; prev_char == ch end
  def curr_is? ch; curr_char == ch end
  def next_is? ch; next_char == ch end

  def prev_char; @text[ @position-1 ] end
  def curr_char; @text[ @position   ] end
  def next_char; @text[ @position+1 ] end
end