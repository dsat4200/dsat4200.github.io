import os
from jinja2 import Environment, FileSystemLoader
from bs4 import BeautifulSoup

def generate_project_pages(html_file, template_file, output_dir):
    """Generates individual project pages using a template."""

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
                
                h3_tag = item.find('h3')
                p_tag = item.find('p')
                if h3_tag and p_tag:
                    title = h3_tag.text.strip()
                    description = p_tag.text.strip().replace('\n', ' ')

                    # Sanitize filename
                    filename = title.lower().replace(' ', '-').replace("'", "").replace("!", "").replace(".", "") + '.html'
                    filepath = os.path.join(output_dir, filename)

                    # Render the template
                    html_content = template.render(title=title, img_src=img_src, alt_text=alt_text, description=description)

                    with open(filepath, 'w', encoding='utf-8') as outfile:
                        outfile.write(html_content)
                    print(f"Created {filename}")

if __name__ == "__main__":
    input_html_file = 'concepts.html'
    template_html_file = 'template.html'
    output_directory = 'project-pages'

    os.makedirs(output_directory, exist_ok=True)
    generate_project_pages(input_html_file, template_html_file, output_directory)

