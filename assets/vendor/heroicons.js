const plugin = require('tailwindcss/plugin')
const fs = require('fs')
const path = require('path')

module.exports = plugin.withOptions(() => {
  return ({ addUtilities, theme }) => {
    const icons = {}
    
    // Define the path to heroicons
    const heroiconsPath = path.resolve(__dirname, '../../deps/heroicons/optimized')
    
    // Load 24px solid icons (most commonly used)
    const solidIconsPath = path.join(heroiconsPath, '24', 'solid')
    
    if (fs.existsSync(solidIconsPath)) {
      const iconFiles = fs.readdirSync(solidIconsPath)
      
      iconFiles.forEach(file => {
        if (file.endsWith('.svg')) {
          const iconName = file.replace('.svg', '')
          const iconPath = path.join(solidIconsPath, file)
          
          try {
            const svgContent = fs.readFileSync(iconPath, 'utf8')
            // Extract path data from SVG
            const pathMatch = svgContent.match(/<path[^>]*d="([^"]*)"[^>]*\/?>/g)
            
            if (pathMatch) {
              const className = `.hero-${iconName}`
              icons[className] = {
                'background-image': `url("data:image/svg+xml,${encodeURIComponent(svgContent)}")`,
                'background-repeat': 'no-repeat',
                'background-size': 'contain',
                'display': 'inline-block',
                'width': '1em',
                'height': '1em'
              }
            }
          } catch (err) {
            // Skip files that can't be read
          }
        }
      })
    }
    
    // Add fallback icons if directory doesn't exist
    if (Object.keys(icons).length === 0) {
      // Common heroicons used in the project
      icons['.hero-x-mark'] = {
        'background-image': `url("data:image/svg+xml,${encodeURIComponent('<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.225 4.811a1 1 0 00-1.414 1.414L10.586 12 4.81 17.775a1 1 0 101.414 1.414L12 13.414l5.775 5.775a1 1 0 001.414-1.414L13.414 12l5.775-5.775a1 1 0 00-1.414-1.414L12 10.586 6.225 4.81z"/></svg>')}")`,
        'background-repeat': 'no-repeat',
        'background-size': 'contain',
        'display': 'inline-block',
        'width': '1em',
        'height': '1em'
      }
      
      icons['.hero-check'] = {
        'background-image': `url("data:image/svg+xml,${encodeURIComponent('<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>')}")`,
        'background-repeat': 'no-repeat',
        'background-size': 'contain',
        'display': 'inline-block',
        'width': '1em',
        'height': '1em'
      }
      
      icons['.hero-cog-6-tooth'] = {
        'background-image': `url("data:image/svg+xml,${encodeURIComponent('<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11.828 2.25c-.916 0-1.699.663-1.85 1.567l-.091.549a.798.798 0 01-.517.608 7.45 7.45 0 00-.478.198.798.798 0 01-.796-.064l-.453-.324a1.875 1.875 0 00-2.416.2l-.243.243a1.875 1.875 0 00-.2 2.416l.324.453a.798.798 0 01.064.796 7.448 7.448 0 00-.198.478.798.798 0 01-.608.517l-.55.092a1.875 1.875 0 00-1.566 1.849v.344c0 .916.663 1.699 1.567 1.85l.549.091c.281.047.508.25.608.517.06.162.127.321.198.478a.798.798 0 01-.064.796l-.324.453a1.875 1.875 0 00.2 2.416l.243.243c.648.648 1.67.733 2.416.2l.453-.324a.798.798 0 01.796-.064c.157.071.316.137.478.198.267.1.47.327.517.608l.092.55c.15.903.932 1.566 1.849 1.566h.344c.916 0 1.699-.663 1.85-1.567l.091-.549a.798.798 0 01.517-.608 7.52 7.52 0 00.478-.198.798.798 0 01.796.064l.453.324a1.875 1.875 0 002.416-.2l.243-.243c.648-.648.733-1.67.2-2.416l-.324-.453a.798.798 0 01-.064-.796c.071-.157.137-.316.198-.478.1-.267.327-.47.608-.517l.55-.092a1.875 1.875 0 001.566-1.849v-.344c0-.916-.663-1.699-1.567-1.85l-.549-.091a.798.798 0 01-.608-.517 7.507 7.507 0 00-.198-.478.798.798 0 01.064-.796l.324-.453a1.875 1.875 0 00-.2-2.416l-.243-.243a1.875 1.875 0 00-2.416-.2l-.453.324a.798.798 0 01-.796.064 7.462 7.462 0 00-.478-.198.798.798 0 01-.517-.608l-.092-.55a1.875 1.875 0 00-1.849-1.566h-.344zM12 15.75a3.75 3.75 0 100-7.5 3.75 3.75 0 000 7.5z"/></svg>')}")`,
        'background-repeat': 'no-repeat',
        'background-size': 'contain',
        'display': 'inline-block',
        'width': '1em',
        'height': '1em'
      }
      
      icons['.hero-arrow-right-start-on-rectangle'] = {
        'background-image': `url("data:image/svg+xml,${encodeURIComponent('<svg viewBox="0 0 24 24" fill="currentColor"><path d="M15.75 8.25a.75.75 0 01.75.75c0 1.12-.492 2.126-1.27 2.812a.75.75 0 11-.992-1.124A2.243 2.243 0 0015 9a.75.75 0 01.75-.75z"/><path fill-rule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zM4.575 15.6a8.25 8.25 0 009.348 4.425 1.966 1.966 0 00-1.84-1.275.983.983 0 01-.97-.822l-.073-.437c-.094-.565.25-1.11.8-1.267l.99-.282c.427-.123.783-.418.982-.816l.036-.073a1.453 1.453 0 012.328-.377L16.5 15h.628a2.25 2.25 0 005.201 1.532A8.25 8.25 0 004.575 15.6z" clip-rule="evenodd"/></svg>')}")`,
        'background-repeat': 'no-repeat',
        'background-size': 'contain',
        'display': 'inline-block',
        'width': '1em',
        'height': '1em'
      }
    }
    
    addUtilities(icons)
  }
})