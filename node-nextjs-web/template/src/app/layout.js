import './globals.css'

export const metadata = {
    title: 'Next.js Service',
    description: 'Scaffolding via Backstage',
}

export default function RootLayout({ children }) {
    return (
        <html lang="en">
            <body>{children}</body>
        </html>
    )
}
