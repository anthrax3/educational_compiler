machines_path = 'machines.txt'
machine_h_path = 'machine.h'
machine_c_path = 'machine.c'
ape_c_path = 'ape.c'
tables_c_path = 'tables.c'
actions_h = 'actions.h'
actions_c = 'actions.c'

special_transitions = []
machines = {}
machine = -1
tokens = []

# read the machines.txt generated by radiant fire (Hugo Barauna)
File.open(machines_path).readlines.each do |line|
  if line[0,1] == '@'
    # special token-machine transitions
    special_transitions = line.split('=')[1].gsub(/\[|\]|\n/, '').split(',').collect{|x| x.strip}
  elsif line[0,1] == '*'
    # load a new machine
    machine += 1
    machines[machine] = {}
    machines[machine]['name'] = line.gsub(/\*|\n/, '')
    machines[machine]['token_transitions'] = {}
    machines[machine]['machine_transitions'] = {}
    machines[machine]['states'] = []
  elsif line[0,1] == 'i'
    # initial state
    machines[machine]['initial'] = line.split(':')[1].gsub(/\n/, '').to_i
  elsif line[0,1] == 'f'
    # final state
    machines[machine]['final'] = line.split(':')[1].gsub(/\n/, '').split(',').collect{|x| x.to_i}
  elsif line[0,1] == '('
    # transition
    from = line.match(/\(([0-9]+)\,/)[1].to_i
    to = line.match(/\-\> ([0-9]+)/)[1].to_i
    read = line.match(/\, (\".+\"|[a-zA-Z0-9]+)\)/)[1]
    if read[0,1] == '"'
      machines[machine]['token_transitions'][from] = {} if machines[machine]['token_transitions'][from].nil?
      machines[machine]['token_transitions'][from][read] = to
      tokens.push read
    else
      if special_transitions.index(read)
        machines[machine]['token_transitions'][from] = {} if machines[machine]['token_transitions'][from].nil?
        machines[machine]['token_transitions'][from][read] = to
        tokens.push read
      else
        machines[machine]['machine_transitions'][from] = {} if machines[machine]['machine_transitions'][from].nil?
        machines[machine]['machine_transitions'][from][read] = to
      end
    end
    machines[machine]['states'].push from
    machines[machine]['states'].push to
  end
end

machines.each do |machine, val|
  machines[machine]['states'].uniq!.sort!
end

def special_cons(special)
  "APE_SPECIAL_TOKEN_#{special.upcase}_ID"
end

FIXED_CHARS = {
  '{' => 'abre_chaves',
  '}' => 'fecha_chaves',
  '(' => 'abre_parenteses',
  ')' => 'fecha_parenteses',
  ';' => 'ponto_e_virgula',
  ',' => 'virgula',
  '=' => 'igual',
  '+' => 'soma',
  '-' => 'subtracao',
  '*' => 'multiplicacao',
  '/' => 'divisao',
  '<' => 'menor',
  '<=' => 'menor_igual',
  '>' => 'maior',
  '>=' => 'maior_igual',
  '==' => 'igual_igual',
  '!=' => 'diferente'
}

def token_cons(token)
  token = token.gsub('"','')
  token = FIXED_CHARS[token] unless FIXED_CHARS[token].nil?
  "APE_TOKEN_#{token.upcase}_ID"
end

def machine_cons(machine)
  "APE_MACHINE_#{machine['name'].upcase}_ID"
end

# generate a list of tokens with their ids
token_ids = {}
i = 0
tokens.uniq.each do |token|
  token_ids[token_cons(token)] = [i, token]
  i += 1
end

# generate a list of machines with ther ids
machines_ids = {}
i = 0
machines.each do |index, machine|
  machines_ids[machine_cons(machine)] = [i, machine['name']]
  i += 1
end

# create all transitions for each machine
machines.each do |index, machine|
  token_transitions = {}
  machine_transitions = {}
  
  states = machine['states']
  states.each do |s|
    
    # create all token transitions for each machine
    token_ids.each do |token, val|
      if machine['token_transitions'][s].nil? or machine['token_transitions'][s][val[1]].nil?
        to = 'APE_INVALID_STATE'
      else
        to = machine['token_transitions'][s][val[1]]
      end
      token_transitions[s] = {} if token_transitions[s].nil?
      token_transitions[s][token] = to
    end
    
    # create all machine transitions for each machine
    machines_ids.each do |machine_id, val|
      
      if machine['machine_transitions'][s].nil? or machine['machine_transitions'][s][val[1]].nil?
        to = 'APE_INVALID_STATE'
      else
        to = machine['machine_transitions'][s][val[1]]
      end
      
      machine_transitions[s] = {} if machine_transitions[s].nil?
      machine_transitions[s][machine_id] = to
      
    end
    
  end
  machine['token_transitions'] = token_transitions
  machine['machine_transitions'] = machine_transitions
end

# create all token machine transitions for each machine


# write the transitions to output files
File.open(machine_h_path, 'w') do |f|
  # needed structs
  f.write "//////////////////////////////////////////////////////////
////////// GENERATED BY RADIANT FIRE LOADER //////////////
//////////////////////////////////////////////////////////

#define\t\tAPE_TOTAL_MACHINES\t\t#{machines.size}
"
    
  f.write "\n/* ape invalid transition */\n"
  f.write "#define\t\tAPE_INVALID_STATE\t\t-1\n"
  
  f.write "\n/* ape machine ids */\n"
  machines_ids.sort{|a,b| a[1] <=> b[1]}.each do |machine, val|
    f.write "#define\t\t#{machine}\t\t#{val[0]}\n"
  end
  
  f.write "\n/* ape tokens ids */\n"
  token_ids.sort{|a,b| a[1] <=> b[1]}.each do |token, val|
    f.write "#define\t\t#{token}\t\t#{val[0]}\n"
  end
  
  f.write "\n//////////////////////////////////////////////////////////"
end

File.open(machine_c_path, 'w') do |f|
  f.write "//////////////////////////////////////////////////////////
////////// GENERATED BY RADIANT FIRE LOADER //////////////
//////////////////////////////////////////////////////////

void init_ape_machines() {
"

  initial_machine = machines[0]
  machines_names = machines_ids.values.sort{|a,b| a[0] <=> b[0]}.collect{|x| x[1]}
  f.write "\t/* load machines */
  Machine #{machines_names.join(', ')};
  
"
  
  machines.sort.each do |index, machine|
    f.write "\n\t/* Machine #{index}: #{machine['name']} */
  #{machine['name']}.machine_id = #{machine_cons(machine)}; // #{index}
  #{machine['name']}.initial_state = #{machine['initial']};
  #{machine['name']}.current_state = #{machine['initial']};
  initialize_machine_transitions(&#{machine['name']});
"
    i = 0
    machine['final'].each do |final|
      f.write "\t#{machine['name']}.final_states[#{i}] = #{final};\n"
      i += 1
    end
    f.write "\t#{machine['name']}.final_states[#{i}] = -1;\n"
    
    f.write "\n\t/* token transitions */\n"
    machine['token_transitions'].sort.each do |from, read_to|
      read_to.sort.each do |read, to|
        f.write "\t#{machine['name']}.token_transitions\t\t[#{from}][#{read}]\t\t=\t\t#{to};\n" if to != 'APE_INVALID_STATE'
      end
    end
    
    f.write "\n\t/* machine transitions */\n"
    machine['machine_transitions'].sort.each do |from, read_to|
      read_to.sort.each do |read, to|
        f.write "\t#{machine['name']}.machine_transitions\t\t[#{from}][#{read}]\t\t=\t\t#{to};\n" if to != 'APE_INVALID_STATE'
      end
    end
    
  end
  
  f.write "
  /* initialize ape machines */
  ape_parser.initial_machine = #{initial_machine['name']};
  ape_parser.current_machine = #{initial_machine['name']};
"
  i = 0
  machines_names.each do |name|
    f.write "\tape_parser.machines[#{i}] = #{name};\n"
    i += 1
  end

  f.write "}\n"

  f.write "\n//////////////////////////////////////////////////////////"

end

File.open(ape_c_path, 'w') do |f|
  f.write "//////////////////////////////////////////////////////////
////////// GENERATED BY RADIANT FIRE LOADER //////////////
//////////////////////////////////////////////////////////

"
  
  token_ids.sort{|a,b| a[1] <=> b[1]}.each do |token, val|
    f.write"
if (strcmp(token.value, \"#{val[1].gsub('"','')}\") == 0) {
	return #{token};
}
"
  end
  
  f.write "\n//////////////////////////////////////////////////////////"
end

File.open(tables_c_path, 'w') do |f|
  f.write "//////////////////////////////////////////////////////////
////////// GENERATED BY RADIANT FIRE LOADER //////////////
//////////////////////////////////////////////////////////

"
  
  token_ids.sort{|a,b| a[1] <=> b[1]}.each do |token, val|
    f.write"add(&table_reserved_words, \"#{val[1].gsub('"','')}\");\n"
  end
  
  f.write "\n//////////////////////////////////////////////////////////"
end

File.open(actions_h, 'w') do |f|
end

File.open(actions_c, 'w') do |f|
  f.write "//////////////////////////////////////////////////////////
////////// GENERATED BY RADIANT FIRE LOADER //////////////
//////////////////////////////////////////////////////////

void init_semantic_actions() {
"
  
  machines.sort.each do |index, machine|
    f.write "\n\t/* Machine #{index}: #{machine['name']} */\n"
    
    f.write "\n\t/* token transitions */\n"
    machine['token_transitions'].sort.each do |from, read_to|
      read_to.sort.each do |read, to|
        f.write "\tsemantic_functions_tokens \t\t [#{index}][#{from}][#{read}]\t\t=\t\tdefault_action;\n" if to != 'APE_INVALID_STATE'
      end
    end
    
    f.write "\n\t/* machine transitions */\n"
    machine['machine_transitions'].sort.each do |from, read_to|
      read_to.sort.each do |read, to|
        f.write "\tsemantic_functions_machines \t\t [#{index}][#{from}][#{read}]\t\t=\t\tdefault_action;\n" if to != 'APE_INVALID_STATE'
      end
    end
    
    f.write "\n\t/* ações semânticas de saída */\n"
    machine['states'].sort.each do |s|
      f.write "\tsemantic_funcions_saida \t\t [#{index}][#{s}]\t\t=\t\tdefault_action;\n"
    end
    
  end

  f.write "}\n"

  f.write "\n//////////////////////////////////////////////////////////"
end