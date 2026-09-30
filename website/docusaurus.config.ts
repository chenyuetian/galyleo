import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'galyleo',
  tagline: 'Launch Jupyter on high-performance computing systems in a simple, secure way.',

  headTags: [
    {
      tagName: 'link',
      attributes: {
        rel: 'icon',
        type: 'image/svg+xml',
        href: '/img/galyleo-blue.svg',
        media: '(prefers-color-scheme: light)',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'icon',
        type: 'image/svg+xml',
        href: '/img/galyleo-orange.svg',
        media: '(prefers-color-scheme: dark)',
      },
    },
  ],

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://mkandes.github.io',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/galyleo/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'mkandes', // Usually your GitHub org/user name.
  projectName: 'galyleo', // Usually your repo name.

  // The name of the deployment branch. It defaults to 'gh-pages' for
  // non-organization GitHub Pages repos (projectName not ending in
  // .github.io). Otherwise, it needs to be explicit as a config field
  // or environment variable.
  deploymentBranch: 'master',

  // GitHub Pages adds a trailing slash to Docusaurus URLs by default. 
  // It is recommended to set a trailingSlash config (true or false,
  // not undefined).
  trailingSlash: false,

  onBrokenLinks: 'throw',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          // Base URL to edit your site. The final URL is computed by
          // editUrl + relativeDocPath. Using a function allows more
          // nuanced control for each file. Omitting this variable
          // entirely will disable edit links.
          editUrl:
            'https://github.com/mkandes/galyleo/tree/master',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    //image: 'img/galyleo-social.png',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'galyleo',
      logo: {
        alt: 'galyleo Logo',
        src: 'img/galyleo-blue.svg',
        srcDark: 'img/galyleo-orange.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          href: 'https://github.com/sdsc/galyleo',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Quick Start Guide',
              to: '/docs/intro',
            },
          ],
        },
        {
          title: 'Systems',
          items: [
            {
              label: 'Expanse',
              href: 'https://www.sdsc.edu/systems/expanse/index.html',
            },
            {
              label: 'TSCC',
              href: 'https://www.sdsc.edu/systems/tscc/index.html',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'San Diego Supercomputer Center',
              href: 'https://sdsc.edu',
            },
            //{
            //  label: 'Halıcıoğlu School of Data Science and Computing',
            //  href: 'https://hsdsc.ucsd.edu',
            //},
            //{
            //  label: 'University of California San Diego',
            //  href: 'https://ucsd.edu',
            //},
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()}, Regents of the University of California.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
