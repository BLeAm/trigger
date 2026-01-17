import sys,os
from typing import Callable, Any


_trigger_list = []

class TriggerCls:
  def __init__(self, cls):
    self.name = cls.__name__
    self.attrs = {}
    for attr in cls.__annotations__:
      type_name = ''
      if cls.__annotations__[attr] == str:
        type_name = 'String'
      elif cls.__annotations__[attr] == int:
        type_name = 'int'
      elif cls.__annotations__[attr] == bool:
        type_name = 'bool'
      elif cls.__annotations__[attr] == float:
        type_name = 'double'
      else:
        type_name = str(cls.__annotations__[attr])
      item:dict[str, Any] = {'type': type_name}
      if attr in cls.__dict__:
        item['value'] = str(cls.__dict__[attr])
        if item['value'] in ['True', 'False']: item['value'] = item['value'].lower()
      else:
        item['value'] = None
      self.attrs[attr] = item
    
  
  def __str__(self):
    res = ''
    init_val = ''
    f_body = ''
    st_body = ''
    for attr in self.attrs:
      res += f'\t{self.attrs[attr]["type"]} get {attr} => getValue(\'{attr}\')'
      st_body += f'\tset {attr}({self.attrs[attr]["type"]} val) => _map["{attr}"] = val;\n'
      if self.attrs[attr]['type'][-1] != '?':
        res += '!'
      res += ';\n'
      res += f'\tset {attr}({self.attrs[attr]["type"]} val) => setValue(\'{attr}\', val);\n'
      val = self.attrs[attr]['value']
      
      if self.attrs[attr]['type'] == 'String':
        val = f"'{val}'"
      if val == None:
        val = 'null'

      init_val += f'\t\t{attr} = {val};\n'

      # ---- Field Part ----
      f_body += f"""
      {self.name}Field get {attr} {{
        addField('{attr}');
        return this;
      }}
      """
      
    res = f'''base class {self.name} extends Trigger {{
    static final {self.name} _instance = {self.name}._internal();
    static {self.name}Field fields() => {self.name}Field();

      {self.name}._internal() {{
{init_val}
      }}

      
      //this will be used to spawn a new {self.name} instance that is not singleton.
      factory {self.name}.spawn() {{
        return {self.name}._internal();
      }}

      factory {self.name}() {{
        return {self.name}._instance;
      }}
{res}

void multiSet(void Function(_{self.name}MultiSetter setter) func) {{
    final setter = _{self.name}MultiSetter();
    func(setter);
    setMultiValues(setter._map);
  }}
    }}\n
    '''
    res = f'''
    {res}
class {self.name}Field extends TriggerField {{
    {f_body}
}}

class _{self.name}MultiSetter {{
  final _map = <String, dynamic>{{}};
  {st_body}
}}
    '''
    return res


def trigger(cls):
  res = TriggerCls(cls)
  _trigger_list.append(res)

def build():
  filename = sys.argv[0].replace('.py','')
  res = '// GENERATED CODE - DO NOT MODIFY BY HAND\n\n'
  res += f"part of '{filename}.dart';\n\n"
  for cls in _trigger_list:
    res += str(cls)
  
  with open(filename+'.g.dart','w') as file:
    file.write(res)
  
  os.system(f'dart format {filename}.g.dart')