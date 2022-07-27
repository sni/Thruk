const colors = require('tailwindcss/colors')
let plugin = require('tailwindcss/plugin')

module.exports = {
  important: true,
  content: [
     '../../../templates/*.tt',
     '../../../plugins/plugins-available/*/templates/*.tt',
     '../../../root/thruk/javascript/*.js',
     '../../../plugins/plugins-available/*/root/*.js',
  ],
  safelist: [
  '.UP', '.OK', '.WARNING', '.UNKNOWN', '.DOWN', '.CRITICAL', '.UNREACHABLE', '.PENDING', '.PROBLEMS'
  ],
  theme: {
    extend: {
      backgroundColor: ['odd'],
      backgroundColor: ['even'],
      fontSize: {
        default: ["13px", "18px"],
        header: ["15px", "22px"],
      },
      colors: {
        // generated with https://javisperez.github.io/tailwindcolorshades/?havelock-blue=6688cc
        'river-bed': {
            '50': '#f6f7f7',
            '100': '#eceef0',
            '200': '#d0d5d8',
            '300': '#b3bbc1',
            '400': '#7b8993',
            '500': '#425664',
            '600': '#3b4d5a',
            '700': '#32414b',
            '800': '#28343c',
            '900': '#202a31'
        },
        'amber': colors.amber,
        'truegray': colors.neutral,
        'warmgray': colors.stone,
        'orange': colors.orange,
        'lime': colors.lime,
      },
      boxShadow: {
        card:  '0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24)',
        float: '5px 5px 10px 0px rgba(0,0,0,0.5);',
      }
    }
  },
  variants: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/forms'),
    plugin(function ({ addVariant }) {
      // Add a `second` variant, ie. `second:pb-0`
      addVariant('second', '&:nth-child(2)')
    }),
    // https://gist.github.com/Merott/d2a19b32db07565e94f10d13d11a8574
    function({ addBase, theme }) {
      function extractColorVars(colorObj, colorGroup = '') {
        return Object.keys(colorObj).reduce((vars, colorKey) => {
          const value = colorObj[colorKey];

          const newVars =
            typeof value === 'string'
              ? { [`--color${colorGroup}-${colorKey}`]: value }
              : extractColorVars(value, `-${colorKey}`);

          return { ...vars, ...newVars };
        }, {});
      }

      addBase({
        ':root': extractColorVars(theme('colors')),
      });
    }
  ],
}
