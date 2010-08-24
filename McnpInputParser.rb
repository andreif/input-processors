class Mcnp::Input::Parser
  def parse(text, nxt = '&', indent = 5)
    
    # // if no text provided
    # if (!$text) return false;
    # 
    # // if text provided as string
    # if (is_string($text)) {
    # 
    #     // then convert it to array of lines
    #     $text = explode("\n", $text);
    # }
    # 
    # // card number initialization
    # $i = -1;
    # 
    # // loop on non-empty lines
    # foreach ($text as $line) if (trim($line)) {
    # 
    #     // remove tab by four spaces
    #     $line = str_replace("\t", '    ', $line);
    # 
    #     // check if it is new card
    #     if (!$multi && (substr($line, 0, $indent) != str_repeat(' ', $indent))) {
    #         $i++;
    #     }
    # 
    #     // add line to card
    #     $result[$i][] = $line;
    # 
    #     // check for multi-line sign
    #     $multi = (substr(rtrim($line), -strlen($next)) == $next);
    # }
    # 
    # // merge card lines
    # foreach ($result as $k => $v) {
    #     $result[$k] = implode("\n", $v);
    # }
    # 
    # return $result;
  end
end