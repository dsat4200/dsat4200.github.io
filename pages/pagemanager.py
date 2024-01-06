import sys
# Number of pages you want to generate
num_pages = int(sys.argv[1])

# Loop to generate pages
for page in range(1, num_pages+1):
    # Define the previous and next page numbers
    prev_page = page - 1
    next_page = page + 1

    # HTML template for each page
    html_template = f'''


<!DOCTYPE html>
<html>

<head>
    <meta charset="UTF-8">
    <title>Page PAGE | Joules + Igor</title>
    <link rel="stylesheet" href="../style.css">
</head>

<body>
    <header>
        <h1 class="header_img">
            Joules + Igor
        </h1>
        <br>
        <nav>
            <ul>
                <li><a href="../index.html">Home</a></li>
                <li><a href="../about.html">About</a></li>
                <li><a href="../notes.html">Production Notes</a></li>
                <li><a href="../readcomic.html">Read Comic</a></li>
            </ul>
        </nav>
    </header>

    <main>
        <section class="comic-page">
            <h2></h2>
        </section>

        <div class="comic-page">
            <button class="prev-page-btn"><a href="1_PREV.html"><</a></button>
            <img src="../pg/1_PAGE.png" alt="Page 1" class="page-image">
            <button class="next-page-btn"><a href="1_NEXT.html">></a></button>
        </div>


    </main>



</body>

</html>
    
    '''
    html_template = html_template.replace("PAGE", f'{page:03d}')

    if(page == 1):
        html_template = html_template.replace("NEXT", f'{next_page:03d}')
        html_template = html_template.replace('PREV.html"><</a></button>',f'{page:03d}.html">.</a></button>')
        
    elif(page !=num_pages):
        html_template = html_template.replace("NEXT", f'{next_page:03d}')
        html_template = html_template.replace("PREV", f'{prev_page:03d}')

    else:
        html_template = html_template.replace('NEXT.html">></a></button>',f'{page:03d}.html">.</a></button>')
        html_template = html_template.replace("PREV", f'{prev_page:03d}')

# Save the HTML to a file
    with open(f'1_{page:03d}.html', 'w') as file:
        file.write(html_template)

print(f'{num_pages} HTML pages generated.')