import os
from jinja2 import Environment, FileSystemLoader
from bs4 import BeautifulSoup
import re

def generate_project_pages(html_file, template_file, output_dir):
    """Generates individual project pages, adding images from the project directory, placing them after the hero image."""

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

                h4_tag = item.find('h4')
                h3_tag = item.find('h3')
                p_tag = item.find('p')
                if h4_tag and h3_tag and p_tag:
                    year = h4_tag.text.strip()
                    title = h3_tag.text.strip()
                    description = p_tag.text.strip().replace('\n', ' ')

                    # Sanitize filename
                    sanitized_title = title.lower().replace(' ', '-').replace("'", "").replace("!", "").replace(".", "")
                    project_dir = os.path.join(output_dir, sanitized_title)
                    os.makedirs(project_dir, exist_ok=True)
                    filename = os.path.join(project_dir, "project.html")

                    # Adjust image path if it's a local image
                    if not re.match(r'https?:\/\/', img_src):
                        img_src = os.path.join('../..', img_src)

                    # Render the basic template first
                    html_content = template.render(title=title, year=year, img_src=img_src, alt_text=alt_text, description=description, additional_images="")

                    with open(filename, 'w', encoding='utf-8') as outfile:
                        outfile.write(html_content)

                    # Find and add additional images AFTER writing the main HTML
                    additional_images = ""
                    try:
                        for image_filename in os.listdir(project_dir):
                            if image_filename.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp')):
                                additional_images += f'<img src="{image_filename}" alt="{title} image">\n'

                        #Find the closing </main> tag and insert additional images before it.
                        with open(filename, 'r') as f:
                            html_content = f.read()

                        #Use a more robust method to find the closing </main> tag in case it's not the last tag in the main body.
                        closing_main_index = html_content.rfind("</main>")
                        if closing_main_index != -1:
                            new_html_content = html_content[:closing_main_index] + f"<div id='additional-images'>{additional_images}</div>" + html_content[closing_main_index:]

                            with open(filename, 'w') as outfile:
                                outfile.write(new_html_content)
                        else:
                            print(f"Warning: Could not find closing </main> tag in {filename}")

                    except FileNotFoundError:
                        print(f"Warning: No images found in directory: {project_dir}")
                    except Exception as e:
                        print(f"An error occurred processing {project_dir}: {e}")

                    print(f"Created {filename}")

if __name__ == "__main__":
    input_html_file = 'index.html'
    template_html_file = '3dtemplate.html'
    output_directory = '3d-project-pages'

    os.makedirs(output_directory, exist_ok=True)
    generate_project_pages(input_html_file, template_html_file, output_directory)
