import { setTimeout } from 'timers/promises';
import CleanCss from 'clean-css';
import fs from 'fs-extra';
import minify from 'minify';
import path from 'path';
import { fileURLToPath } from 'url';
import UglifyJS from 'uglify-js';
import axios from 'axios';
import shiki from 'shiki';
import yaml from 'js-yaml';
import rehypeFormat from 'rehype-format';
import rehypeRaw from 'rehype-raw'
import rehypeDocument from 'rehype-document';
import rehypeStringify from 'rehype-stringify';
import remarkFrontmatter from 'remark-frontmatter';
import remarkGfm from 'remark-gfm';
import remarkParse from 'remark-parse';
import remarkRehype from 'remark-rehype';
import remarkSlug from 'remark-slug';
import remarkToc from 'remark-toc';
import { unified } from 'unified';
import { visit } from 'unist-util-visit';
import { JSDOM } from 'jsdom';

const INTERNAL = [ 'base.html', 'config.json', 'index.md' ];

const normalizeDir = (s) => {
  return s.endsWith('/') ? s.slice(0, -1) : s;
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const cfg = fs.readJsonSync(`${__dirname}/generator.json`);
const srcDir = normalizeDir(__dirname.replace('/tools', ''));
const outDir = normalizeDir(`${srcDir}/build`);

// Plugins

const prependTocNode = (options = {}) => {
  return (tree, file) => {
    tree.children = [
      {
        "type": "heading",
        "depth": 6,
        "children": [
          {
            "type": "text",
            "value": "toc",
            "position": {
              "start": {
                "line": 1,
                "column": 8,
                "offset": 7
              },
              "end": {
                "line": 1,
                "column": 11,
                "offset": 10
              }
            }
          }
        ],
        "position": {
          "start": {
            "line": 1,
            "column": 1,
            "offset": 0
          },
          "end": {
            "line": 1,
            "column": 12,
            "offset": 11
          }
        }
      },
      ...tree.children.slice(0)
    ];

    /*
    node.children = [
      ...node.children.slice(0, result.index),
      result.map,
      ...node.children.slice(result.endIndex)
    ]
    */
  }
};

const joinCodeClasses = () => {
  return (tree, file) => {
    visit(tree, 'code', node => {
      if(node.lang || node.meta) {
        node.lang = 
        node.meta==null ? node.lang 
        : node.lang==null ? node.meta.split(' ').join('_')
        : `${node.lang}_${node.meta.split(' ').join('_')}`;
      }
    });
  }
};

const copyFmToConfig = (configJson) => {
  return (tree, file) => {
    visit(tree, 'yaml', (node, index, p) => {
      const fm = yaml.load(node.value, 'utf8');
      for ( const k in fm ) {
        configJson[k] = fm[k];
      }
      p.children.splice(index, 1); // Remove yaml node.
      return [visit.SKIP, index];
    });
  }
};

// Tools

// This is a hack, really we need to have better synchronization across the
// parallel jobs.
const readJsonWait = async (who, f) => {
  while ( true ) {
    if ( await fs.exists(f) ) {
      try { return await fs.readJson(f); }
      catch (e) {
        console.log(`Failed to read ${f}:`, e);
      }
    }
    await setTimeout(1000);
  }
};

const remoteGet_ = async (url) => {
  if ( url.startsWith(cfg.repoBase) ) {
    const n = url.replace(cfg.repoBase, `${__dirname}/../../reach-lang/`);
    try { return await fs.readFile(n, 'utf8'); }
    catch (e) {
      void(e);
    }
  }
  console.log(`Downloading ${url}`);
  return (await axios.get(url)).data;
};
const CACHE = {};
const remoteGet = async (url) => {
  if ( ! (url in CACHE) ) {
    CACHE[url] = await remoteGet_(url);
  }
  return CACHE[url];
};

let shikiHighlighter = undefined;
const shikiHighlight = async (code, lang) => {
  if ( shikiHighlighter === undefined ) {
    shikiHighlighter = await shiki.getHighlighter({ theme: 'github-light' });
  }
  return shikiHighlighter.codeToHtml(code, lang);
};

// Library
const cleanCss = new CleanCss({level: 2});
const processCss = async () => {
  const iPath = `${srcDir}/assets.in/styles.css`;
  const oPath = `${outDir}/assets/styles.min.css`;
  console.log(`Minifying ${iPath}`);
  const input = await fs.readFile(iPath, 'utf8');
  const output = cleanCss.minify(input);
  await fs.writeFile(oPath, output.styles);
};

const processBaseHtml = async (lang) => {
  const iPath = `${srcDir}/${lang}/base.html`;
  const oPath = `${outDir}/${lang}/index.html`;
  console.log(`Minifying ${iPath}`);
  const output = await minify(iPath, { html: {} });
  await fs.writeFile(oPath, output);
};

const processJs = async () => {
  const iPath = `${srcDir}/assets.in/scripts.js`;
  const oPath = `${outDir}/assets/scripts.min.js`;
  console.log(`Minifying ${iPath}`);
  const input = await fs.readFile(iPath, 'utf8');
  const output = new UglifyJS.minify(input, {});
  if (output.error) throw output.error;
  await fs.writeFile(oPath, output.code);
}

const evaluateCodeSnippet = (code) => {
  const spec = {
    "numbered": true,
    "language": null, // indicates highlighted
    "url": null,      // indicates loaded
    "range": null     // indicates ranged
  };

  if (code.classList && code.classList.length == 1 && code.classList[0].startsWith('language')) {
    const arrLC = code.classList[0].replace('language-', '').split('_');
    for (let i = 0; i < arrLC.length; i++) {
      if (arrLC[i] == 'unnumbered' || arrLC[i] == 'nonum') {
        spec.numbered = false;
      } else {
        spec.language = arrLC[i];
      }
    }
  }

  const arr = code.textContent.trimEnd().split(/\r?\n/g);
  if (arr.length > 0) {
    const line1 = arr[0].replace(/\s+/g, '');
    if (line1.slice(0, 5) == 'load:') {
      const url = line1.slice(5);
      if (url.slice(0, 4) == 'http') { spec.url = url; }
      else { spec.url = `${cfg.repoBase}${url}`; }
      if (arr.length > 1) {
        const line2 = arr[1].replace(/\s+/g, '');
        if (line2.slice(0, 6) == 'range:') {
          spec.range = line2.slice(6);
        }
      }
    }
  }
  return spec;
}

const processCodeSnippet = (doc, pre, code, spec) => {
  let firstLineIndex = null;
  let lastLineIndex = null;
  if (spec.range) {
    const rangeArr = spec.range.split('-');
    firstLineIndex = rangeArr[0] - 1;
    if (rangeArr.length > 1) {
      lastLineIndex = rangeArr[1] - 1;
    }
  }

  const arr = code.textContent.split(/\r?\n/g);
  let olStr = '<ol class="snippet">';
  for (let i = 0; i < arr.length; i++) {

    if (firstLineIndex && i < firstLineIndex) {
      continue;
    } else if (lastLineIndex && lastLineIndex < i) {
      break;
    }

    olStr += `<li value="${i + 1}">${arr[i]}</li>`;

  }
  olStr += '</ol>';
  code.remove();
  const olEl = doc.createRange().createContextualFragment(olStr);
  pre.append(olEl);
  pre.classList.add('snippet');
  pre.classList.add(spec.numbered ? 'numbered' : 'unnumbered');
}

const transformReachDoc = (md) => {
  const match1 = /# {#(.*)}/; // Example: # {#guide-ctransfers}
  const match2 = '```reach';
  const match3 = /\${toc}/;

  const mdArr = md.split('\n');
  md = '';
  for (let i = 0; i < mdArr.length; i++) {
    let line = mdArr[i];

    if (line.match(match1)) { line = line.replace(match1, '#'); }
    if (line.match(match2)) { line = line.replace(match2, '```js'); }
    if (line.match(match3)) { line = line.replace(match3, ''); }

    md += `${line}\n`;
  }
  return md;
}

const processFolder = async ({relDir, in_folder, out_folder}) => {
  const lang = relDir.split('/')[0];
  const mdPath = `${in_folder}/${cfg.mdFile}`;
  const cfgPath = `${out_folder}/${cfg.cfgFile}`;
  const pagePath = `${out_folder}/${cfg.pageFile}`;
  const otpPath = `${out_folder}/${cfg.otpFile}`;

  console.log(`Building page ${relDir}`);

  // Create fresh config file with default values.
  const configJson = {
    author: null,
    background: 'white',
    bookPath: null,
    bookTitle: null,
    chapters: null,
    hasOtp: true,
    hasCustomBase: false,
    hasEditBtn: cfg.hasEditBtn,
    hasPageHeader: true,
    hasPageScrollbar: true,
    hasRefreshBtn: cfg.hasRefreshBtn,
    menuItem: null,
    pages: null,
    pathname: null,
    publishedDate: null,
    title: null,
  };

  /*
  const docOptions = {
    "title": "Reach Developer Portal",
    "link": [
      { "rel": "icon", "type": "image/png", "href": "/assets/favicon.png" },
      { "rel": "stylesheet", "type": "text/css", "href": "https://cdn.jsdelivr.net/npm/bootstrap@5.1.0/dist/css/bootstrap.min.css" },
      { "rel": "stylesheet", "type": "text/css", "href": "https://use.fontawesome.com/releases/v5.6.3/css/all.css" },
      { "rel": "stylesheet", "type": "text/css", "href": "/assets/styles.min.css" }
    ]
  };
  */

  let md = await fs.readFile(mdPath, 'utf8');

  // If src == remote, get the remote markdown..
  const re = /---([\s\S]*?)---/;
  const fm = md.match(re);
  if (fm) {
    const fmArr = fm[0].split('\n');
    for (let i = 0; i < fmArr.length; i++) {
      const s = fmArr[i].replaceAll(' ', '').trim();
      if (s.substring(0, 4) === 'src:') {
        const target = `${cfg.repoSrcDir}${s.substring(4)}`;
        const url = `${cfg.repoBase}${target}`;
        const content = (await remoteGet(url));
        md = fm[0] + '\n' + transformReachDoc(content);
        break;
      }
    }
  }

  // markdown-to-html pipeline.
  const output = await unified()
    .use(remarkParse) // Parse markdown to Markdown Abstract Syntax Tree (MDAST).
    .use(remarkFrontmatter) // Prepend YAML node with frontmatter.
    .use(copyFmToConfig, configJson) // Remove YAML node and write frontmatter to config file.
    .use(prependTocNode) // Prepend Heading, level 6, value "toc".
    //.use(() => (tree) => { console.dir(tree); })
    .use(remarkToc, { maxDepth: 2 }) // Build toc list under the heading.
    //.use(() => (tree) => { console.dir(JSON.stringify(tree.children[1].children, null, 2)); })
    .use(remarkSlug) // Create IDs (acting as anchors) for headings throughout the document.
    .use(joinCodeClasses) // Concatenate (using _) class names for code elements.
    .use(remarkGfm) // Normalize Github Flavored Markdown so it can be converted to html.
    .use(remarkRehype, { allowDangerousHtml: true }) // Convert MDAST to html.
    .use(rehypeRaw) // Copy over html embedded in markdown.
    //.use(rehypeDocument, docOptions) // Adds full-page html tags.
    .use(rehypeFormat) // Prettify html.
    .use(rehypeStringify) // Serialize html.
    .process(md); // Push the markdown through the pipeline.

  const doc = new JSDOM(output).window.document;

  // Process OTP.
  if (doc.getElementById('toc')) {
    doc.getElementById('toc').remove();
    const otpEl = doc.querySelector('ul');
    otpEl.querySelectorAll('li').forEach(el => el.classList.add('dynamic'));
    otpEl.querySelectorAll('ul').forEach(el => el.classList.add('dynamic'));
    otpEl.querySelectorAll('p').forEach(el => {
      const p = el.parentNode;
      while (el.firstChild) { p.insertBefore(el.firstChild, el); }
      p.removeChild(el);
    })
    await fs.writeFile(otpPath, `<ul>${otpEl.innerHTML.trim()}</ul>`);
    otpEl.remove();
  }

  // Update config.json with title and pathname.
  const title = doc.querySelector('h1').textContent;
  doc.querySelector('h1').remove();
  configJson.title = title;
  configJson.pathname = in_folder;

  // Update config.json with book information.
  if (configJson.bookTitle) {
    configJson.bookPath = relDir;
  } else {
    const pArray = out_folder.split('/');
    if (pArray.includes('books')) {
      const bArray = pArray.slice(0, pArray.indexOf('books') + 2);
      const bPath = bArray.join('/');
      const bIdArray = pArray.slice(pArray.indexOf('books') - 1, pArray.indexOf('books') + 2);
      configJson.bookPath = bIdArray.join('/');
      const bookConfigJsonFile = `${bPath}/config.json`;
      const bookConfigJson = await readJsonWait(cfgPath, bookConfigJsonFile);
      configJson.bookTitle = bookConfigJson.bookTitle;
    }
  }

  // Adjust image urls.
  doc.querySelectorAll('img').forEach(img => {
    img.src = `/${relDir}/${img.src}`;
  });

  // Process code snippets.
  const preArray = doc.querySelectorAll('pre');
  for (let i = 0; i < preArray.length; i++) {
    const pre = preArray[i];
    const code = pre.querySelector('code');

    // Evaluate code snippet
    if (!code) { continue; }
    const spec = evaluateCodeSnippet(code);

    // Get remote content if specified.
    if (spec.url) {
      code.textContent = await remoteGet(spec.url);
    }

    // Replace < and > with code.
    code.textContent = code.textContent/*.replaceAll('<', '&lt;').replaceAll('>', '&gt;')*/.trimEnd();

    // Highlight the content if specified.
    // https://github.com/shikijs/shiki/blob/main/docs/themes.md
    // https://github.com/shikijs/shiki/blob/main/docs/languages.md
    if (spec.language) {
      const hicode = await shikiHighlight(code.textContent, spec.language);
      code.textContent = hicode
        //.replace('<pre class="shiki" style="background-color: #282A36"><code>', '') // dracula
        .replace('<pre class="shiki" style="background-color: #ffffff"><code>', '') // github-light
        .replaceAll('<span class="line">', '')
        .replaceAll('</span></span>', '</span>')
        .replace('</code></pre>', '');
    }

    processCodeSnippet(doc, pre, code, spec);
  }

  // Create soft link in this folder to index.html file at root.
  if(configJson.hasCustomBase == false) {
    try { await fs.unlink(`${out_folder}/index.html`); } catch (e) { void(e); }
    const backstepCount = relDir.split('/').length - 1;
    let backstepUrl = '';
    for (let i=0; i < backstepCount; i++) {
      backstepUrl = backstepUrl + '../';
    }
    const target = `${backstepUrl}index.html`;
    const symlink = `${out_folder}/index.html`;
    await fs.symlink(target, symlink);
  }

  // Write files
  await Promise.all([
    fs.writeFile(cfgPath, JSON.stringify(configJson, null, 2)),
    fs.writeFile(pagePath, doc.body.innerHTML.trim()),
  ]);
};

const findAndProcessFolder = async (folder) => {
  let relDir = normalizeDir(folder.replace(srcDir, ''));
  relDir = relDir.startsWith('/') ? relDir.slice(1) : relDir;
  const in_folder = `${srcDir}/${relDir}`;
  const out_folder = `${outDir}/${relDir}`;
  await fs.mkdir(out_folder, { recursive: true })
  const fileArr = await fs.readdir(folder);
  await Promise.all(fileArr.map(async (p) => {
    if ( p === 'index.md' ) {
      return await processFolder({relDir, in_folder, out_folder});
    } else {
      const absolute = path.join(folder, p);
      const s = await fs.stat(absolute);
      if (s.isDirectory()) {
        return await findAndProcessFolder(absolute);
      } else if ( ! INTERNAL.includes(p) ) {
        return await fs.copyFile(path.join(in_folder, p), path.join(out_folder, p));
      }
    }
  }));
};

const processBase = async (lang) => {
  await Promise.all([
    processBaseHtml(lang),
    findAndProcessFolder(`${srcDir}/${lang}`),
  ]);
};

// Main

(async () => {
  await Promise.all([
    processCss(),
    processJs(),
    processBase('en'),
  ]);
})();
