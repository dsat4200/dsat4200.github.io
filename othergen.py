import os
from jinja2 import Environment, FileSystemLoader
from bs4 import BeautifulSoup

def generate_project_pages(html_file, template_file, output_dir):
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
                alt_text = img_tag.get('alt', '')

                h4_tag = item.find('h4')
                h3_tag = item.find('h3')
                p_tag = item.find('p')
                if h3_tag and p_tag:
                    year = h4_tag.text.strip() if h4_tag else None
                    title = h3_tag.text.strip()
                    description = p_tag.text.strip()

                    sanitized_title = title.lower().replace(' ', '-').replace("'", "").replace("!", "").replace(".", "")
                    project_dir = os.path.join(output_dir, sanitized_title)
                    filename = os.path.join(project_dir, "project.html")

                    images = []
                    videos = []
                    try:
                        for f in os.listdir(project_dir):
                            lower = f.lower()
                            if lower.endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp')):
                                base = os.path.splitext(f)[0]
                                caption = None
                                for ext in ['.txt']:
                                    txt_file = base + ext
                                    txt_path = os.path.join(project_dir, txt_file)
                                    if os.path.exists(txt_path):
                                        with open(txt_path, 'r', encoding='utf-8') as tf:
                                            caption = tf.read().strip()
                                        break
                                images.append({'src': f, 'alt': alt_text, 'caption': caption})
                            elif lower.endswith(('.mp4', '.webm')):
                                videos.append({'src': f, 'alt': alt_text})
                    except FileNotFoundError:
                        pass

                    if not os.path.exists(project_dir):
                        os.makedirs(project_dir, exist_ok=True)

                    html_content = template.render(
                        title=title,
                        year=year,
                        description=description,
                        images=images,
                        videos=videos
                    )

                    with open(filename, 'w', encoding='utf-8') as outfile:
                        outfile.write(html_content)

                    print(f"Created {filename}")

if __name__ == "__main__":
    input_html_file = 'other.html'
    template_html_file = 'othertemplate.html'
    output_directory = 'other-stuff'

    os.makedirs(output_directory, exist_ok=True)
    generate_project_pages(input_html_file, template_html_file, output_directory)
