#%%(SimplebusInterconnect_M1_S(\d+))%%
#%%%%
from jinja2 import Template
import argparse
import os

parser = argparse.ArgumentParser(description='Generate Simplebus Interface')
parser.add_argument('target', metavar='TARGET', type=str,
                    help='Directory where the output will be generated')
parser.add_argument('nslaves', metavar='NSLAVES', type=int,
                    help='Number of simplebus slave interfaces')
args = parser.parse_args()



instance_vars = {}
masters_n = 1
slaves_n = args.nslaves
instance_vars['masters_n'] = masters_n
instance_vars['slaves_n'] = slaves_n
instance_vars['masters'] = list(range(1,masters_n+1))
instance_vars['slaves'] = list(range(1,slaves_n+1))


template_path = str(os.path.dirname(os.path.realpath(__file__))) + '/SimplebusInterconnect_M1_Sx.j2'
with open(template_path) as file_:
    template = Template(file_.read())
        
output = template.render(instance_vars)

with open(args.target, 'w') as f:
    f.write(output)