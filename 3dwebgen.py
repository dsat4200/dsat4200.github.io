import os
from jinja2 import Environment, FileSystemLoader
from bs4 import BeautifulSoup
import re

def generate_project_pages(html_file, template_file, output_dir):
    """Generates individual project pages using a template, adjusting image paths."""

    env = Environment(loader=FileSystemLoader('.'))
    template = env.get_template(template_file)

    with open(html_file, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f, 'html.parser')

    project_items = soup.find_all('div', class_='project-item')

    for item in project_items:
        a_tag = item.find('a')
        if a_tag:
            img_tag = item.find('img')
            if img_tag:
                img_src = img_tag['src']
                alt_text = img_tag['alt']

                h4_tag = item.find('h4') # Changed this line
                h3_tag = item.find('h3')
                p_tag = item.find('p')
                if h4_tag and h3_tag and p_tag: # Added h3_tag to the condition
                    year = h4_tag.text.strip() # Changed this line
                    title = h3_tag.text.strip()
                    description = p_tag.text.strip().replace('\n', ' ')

                    # Sanitize filename
                    project_dir = os.path.join(output_dir, title.lower().replace(' ', '-').replace("'", "").replace("!", "").replace(".", ""))
                    os.makedirs(project_dir, exist_ok=True)
                    filename = os.path.join(project_dir, "project.html")

                    # Adjust image path if it's a local image
                    if not re.match(r'https?:\/\/', img_src):
                        img_src = os.path.join('../..', img_src)

                    # Render the template
                    html_content = template.render(title=title, year=year, img_src=img_src, alt_text=alt_text, description=description)

                    with open(filename, 'w', encoding='utf-8') as outfile:
                        outfile.write(html_content)
                    print(f"Created {filename}")

if __name__ == "__main__":
    input_html_file = 'index.html'
    template_html_file = '3dtemplate.html'
    output_directory = '3d-project-pages'

    os.makedirs(output_directory, exist_ok=True)
    generate_project_pages(input_html_file, template_html_file, output_directory)
