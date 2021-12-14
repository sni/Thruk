const colors = require('tailwindcss/colors')

module.exports = {
 /*  mode: 'jit', */
  purge: [
     '../../../templates/*.tt',
     '../../../plugins/plugins-available/*/templates/*.tt'
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
		backgroundColor: ['odd'],
		backgroundColor: ['even'],
      colors: {
        // generated with https://javisperez.github.io/tailwindcolorshades/?havelock-blue=6688cc
        'thruk3': {
            '50': '#f7f9fc',
            '100': '#f0f3fa',
            '200': '#d9e1f2',
            '300': '#c2cfeb',
            '400': '#94acdb',
            '500': '#6688cc',
            '600': '#5c7ab8',
            '700': '#4d6699',
            '800': '#3d527a',
            '900': '#324364'
        },
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
        'amber': {
            '50': '#FFFBEB',
            '100': '#FEF3C7',
            '200': '#FDE68A',
            '300': '#FCD34D',
            '400': '#FBBF24',
            '500': '#F59E0B',
            '600': '#D97706',
            '700': '#B45309',
            '800': '#92400E',
            '900': '#78350F'
        },
		'truegray': colors.trueGray,
		'warmgray': colors.warmGray,
		'orange': colors.orange,
		'lime': colors.lime,
      },
      boxShadow: {
        float: '0 3px 6px 0 rgba(0, 0, 0, 0.36)',
      }
    }
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
