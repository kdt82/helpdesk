<?php
// Blue Moon IT Support Portal - API VERSION
// Standalone Page - Matches Website Colors & Styles exactly
// Uses Resend API via HTTPS (Port 443) for maximum reliability

$RESEND_API_KEY = getenv('RESEND_API_KEY') ?: 're_YOUR_KEY_HERE';

function sendResendEmail($to, $subject, $htmlBody, $apiKey, $replyTo = null) {
    if (strpos($apiKey, 're_') !== 0) {
        return "Error: Invalid or Missing API Key. Please configure RESEND_API_KEY in docker-compose.yml.";
    }

    $payload = [
        'from' => 'Blue Moon Portal <support@bluemoonit.com.au>',
        'to' => $to,
        'subject' => $subject,
        'html' => $htmlBody,
    ];

    if ($replyTo) {
        $payload['reply_to'] = $replyTo;
    }

    $ch = curl_init('https://api.resend.com/emails');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $apiKey,
        'Content-Type: application/json'
    ]);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);

    if ($error) {
        return "Connection Failed: " . $error;
    }

    $data = json_decode($response, true);
    if ($httpCode >= 200 && $httpCode < 300) {
        return true;
    } else {
        return "Send Failed: " . ($data['message'] ?? 'Unknown API Error') . " (HTTP $httpCode)";
    }
}

$message_status = "";
$message_type = "";

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['submit_support'])) {
    $name = htmlspecialchars($_POST['name'] ?? '');
    $email = htmlspecialchars($_POST['email'] ?? '');
    $phone = htmlspecialchars($_POST['phone'] ?? '');
    $service = htmlspecialchars($_POST['service'] ?? '');
    $urgency = htmlspecialchars($_POST['urgency'] ?? 'Medium');
    $summary = htmlspecialchars($_POST['summary'] ?? '');

    $subject = "[$urgency] $service - $name";
    
    // Clean HTML for email
    $bodyHtml = "
    <div style='font-family: sans-serif; max-width: 600px; border: 1px solid #eee; padding: 20px;'>
        <h2 style='color: #031335; border-bottom: 2px solid #1fa3e3; padding-bottom: 10px;'>New Support Request</h2>
        <table style='width: 100%;'>
            <tr><td style='width: 150px; font-weight: bold;'>Name:</td><td>$name</td></tr>
            <tr><td style='font-weight: bold;'>Email:</td><td>$email</td></tr>
            <tr><td style='font-weight: bold;'>Phone:</td><td>$phone</td></tr>
            <tr><td style='font-weight: bold;'>Service:</td><td>$service</td></tr>
            <tr><td style='font-weight: bold;'>Urgency:</td><td>$urgency</td></tr>
        </table>
        <hr style='border: 0; border-top: 1px solid #eee; margin: 20px 0;'>
        <p><strong>Description:</strong></p>
        <p style='white-space: pre-wrap;'>" . nl2br($summary) . "</p>
    </div>";

    $result = sendResendEmail("support@bluemoonit.com.au", $subject, $bodyHtml, $RESEND_API_KEY, $email);
    
    if ($result === true) {
        $message_status = "Your support request has been submitted successfully! We'll be in touch shortly.";
        $message_type = "success";
    } else {
        $message_status = $result;
        $message_type = "error";
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Get Support - Blue Moon IT</title>
    <!-- Montserrat - EXACT WEBSITE FONT -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <!-- Font Awesome for Social Icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        :root {
            --background: #ffffff;
            --foreground: #2a2a2a;
            --primary: #031335;
            --secondary: #36597f;
            --accent: #1fa3e3;
            --highlight: #a6a8a7;
            --white-text: #ffffff;
            --button-red: #e63946;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Montserrat', system-ui, -apple-system, sans-serif;
            background: #f8fafc;
            color: var(--foreground);
            line-height: 1.6;
        }

        /* Hero / Header */
        .hero {
            background: linear-gradient(rgba(3, 19, 53, 0.92), rgba(3, 19, 53, 0.95)), url('https://bluemoonit.com.au/assets/hero.jpg');
            background-size: cover;
            background-position: center;
            padding: 30px 0 120px;
            position: relative;
            box-shadow: 0 4px 30px rgba(0,0,0,0.2);
        }

        .moon-vibe {
            position: absolute;
            top: 40px;
            right: 15%;
            width: 140px;
            height: 140px;
            background: radial-gradient(circle at 35% 35%, #5eb1ff, #1fa3e3 50%, #031335);
            border-radius: 50%;
            box-shadow: 0 0 80px rgba(31, 163, 227, 0.4), inset -20px -15px 40px rgba(0,0,0,0.5);
            opacity: 0.85;
            z-index: 1;
        }

        .nav {
            display: flex;
            justify-content: space-between;
            align-items: center;
            max-width: 1100px;
            margin: 0 auto;
            padding: 0 20px;
            position: relative;
            z-index: 10;
        }
        .logo img { height: 48px; }
        
        .nav-links { display: flex; align-items: center; }
        .nav-links a {
            color: var(--white-text);
            text-decoration: none;
            margin-left: 25px;
            font-size: 0.85rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            opacity: 0.9;
            transition: color 0.2s;
        }
        .nav-links a:hover { color: var(--accent); opacity: 1; }

        .hero-content {
            text-align: center;
            padding: 90px 20px 0;
            position: relative;
            z-index: 10;
        }
        .hero-content h1 {
            color: var(--white-text);
            font-size: 2.8rem;
            font-weight: 700;
            margin-bottom: 20px;
            letter-spacing: -0.01em;
        }
        .hero-content p {
            font-size: 1.15rem;
            color: rgba(255,255,255,0.7);
            max-width: 600px;
            margin: 0 auto;
        }

        /* Container & Tabs */
        .portal-wrapper {
            max-width: 800px;
            margin: -70px auto 60px;
            padding: 0 20px;
            position: relative;
            z-index: 30;
        }
        
        .tab-nav {
            display: flex;
            background: rgba(3, 19, 53, 0.9);
            border-radius: 12px 12px 0 0;
            overflow: hidden;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.1);
            border-bottom: none;
        }
        .tab-btn {
            flex: 1;
            padding: 22px;
            border: none;
            background: transparent;
            color: rgba(255,255,255,0.6);
            font-weight: 600;
            font-size: 0.95rem;
            cursor: pointer;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            transition: all 0.3s ease;
        }
        .tab-btn.active {
            background: var(--background);
            color: var(--primary);
        }

        .portal-content {
            background: var(--background);
            border-radius: 0 0 12px 12px;
            padding: 45px;
            box-shadow: 0 25px 60px rgba(0,0,0,0.12);
        }

        .tab-pane { display: none; }
        .tab-pane.active { display: block; }

        /* Form Styling */
        .form-label {
            display: block;
            font-weight: 700;
            color: var(--primary);
            margin-bottom: 12px;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.08em;
        }
        .form-control {
            width: 100%;
            padding: 16px;
            border: 2px solid #edf2f7;
            border-radius: 10px;
            background: #fbfcfe;
            font-size: 1rem;
            font-family: 'Montserrat', sans-serif;
            transition: all 0.2s ease;
        }
        .form-control:focus {
            outline: none;
            border-color: var(--accent);
            background: #fff;
            box-shadow: 0 0 0 5px rgba(31, 163, 227, 0.1);
        }

        .row-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 25px;
            margin-bottom: 25px;
        }
        @media (max-width: 650px) { .row-grid { grid-template-columns: 1fr; } }
        .mb-4 { margin-bottom: 25px; }

        .urgency-wrap {
            display: flex;
            gap: 15px;
        }
        .urgency-box { flex: 1; }
        .urgency-box input { display: none; }
        .urgency-box label {
            display: block;
            padding: 14px;
            text-align: center;
            border: 2px solid #edf2f7;
            border-radius: 10px;
            cursor: pointer;
            font-weight: 600;
            font-size: 0.9rem;
            transition: all 0.2s;
        }
        .urgency-box input:checked + label.l { border-color: #22c55e; background: #f0fdf4; color: #166534; }
        .urgency-box input:checked + label.m { border-color: var(--accent); background: #f0f9ff; color: #0c4a6e; }
        .urgency-box input:checked + label.h { border-color: var(--button-red); background: #fef2f2; color: #991b1b; }

        .btn-main {
            width: 100%;
            padding: 20px;
            background: var(--primary);
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 1.1rem;
            font-weight: 700;
            cursor: pointer;
            text-transform: uppercase;
            letter-spacing: 0.15em;
            transition: all 0.3s;
            margin-top: 15px;
        }
        .btn-main:hover {
            background: var(--accent);
            transform: translateY(-2px);
            box-shadow: 0 12px 24px rgba(31, 163, 227, 0.25);
        }

        /* REAL FOOTER DUPLICATION */
        .main-footer {
            background-color: var(--primary);
            color: var(--white-text);
            padding: 80px 20px 40px;
            font-size: 0.9rem;
        }
        .footer-container {
            max-width: 1100px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: 2fr 1fr 1fr 1fr 1fr;
            gap: 40px;
        }
        @media (max-width: 900px) {
            .footer-container { grid-template-columns: 1fr 1fr; }
            .footer-col.brand { grid-column: span 2; }
        }
        @media (max-width: 600px) {
            .footer-container { grid-template-columns: 1fr; }
            .footer-col.brand { grid-column: span 1; }
        }

        .footer-col h3 {
            color: var(--accent);
            font-size: 1.05rem;
            font-weight: 700;
            margin-bottom: 25px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        .footer-col p { color: rgba(255,255,255,0.7); line-height: 1.8; margin-bottom: 20px; font-size: 0.85rem; }
        .footer-col ul { list-style: none; }
        .footer-col ul li { margin-bottom: 12px; }
        .footer-col ul li a {
            color: rgba(255,255,255,0.7);
            text-decoration: none;
            font-size: 0.85rem;
            transition: color 0.2s;
        }
        .footer-col ul li a:hover { color: var(--accent); }

        .social-icons { display: flex; gap: 15px; margin-top: 20px; }
        .social-icons a {
            width: 36px;
            height: 36px;
            background: rgba(255,255,255,0.05);
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 5px;
            color: white;
            text-decoration: none;
            transition: all 0.2s;
        }
        .social-icons a:hover { background: var(--accent); }

        .footer-bottom {
            max-width: 1100px;
            margin: 60px auto 0;
            padding-top: 30px;
            border-top: 1px solid rgba(255,255,255,0.1);
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
        }
        .footer-bottom p { color: rgba(255,255,255,0.4); font-size: 0.75rem; }
        .footer-bottom .abn {
            color: rgba(31, 163, 227, 0.2);
            text-decoration: none;
            font-size: 0.7rem;
        }
        .footer-bottom .abn:hover { color: var(--accent); }

        /* Admin Portal Style */
        .admin-pane { text-align: center; padding: 70px 20px; }
        .admin-pane h3 { color: var(--primary); margin-bottom: 15px; font-weight: 700; }
        .admin-pane p { color: #666; margin-bottom: 35px; }
        .btn-outline {
            display: inline-block;
            padding: 15px 45px;
            border: 2px solid var(--primary);
            color: var(--primary);
            text-decoration: none;
            border-radius: 10px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            transition: all 0.2s;
        }
        .btn-outline:hover { background: var(--primary); color: white; }

        /* Alert */
        .msg-alert {
            padding: 18px;
            border-radius: 10px;
            text-align: center;
            font-weight: 600;
            margin-bottom: 30px;
        }
        .msg-alert.success { background: #dcfce7; color: #166534; }
        .msg-alert.error { background: #fee2e2; color: #991b1b; }
    </style>
</head>
<body>

<div class="hero">
    <div class="moon-vibe"></div>
    <nav class="nav">
        <a href="https://bluemoonit.com.au" class="logo">
            <img src="https://bluemoonit.com.au/assets/logo.png" alt="Blue Moon IT Logo">
        </a>
        <div class="nav-links">
            <a href="https://bluemoonit.com.au">Home</a>
            <a href="https://bluemoonit.com.au/services">Services</a>
            <a href="https://bluemoonit.com.au/contact">Contact</a>
        </div>
    </nav>
    <div class="hero-content">
        <h1>Professional IT Support</h1>
        <p>Servicing home users and small businesses across the Illawarra with reliable tech solutions.</p>
    </div>
</div>

<div class="portal-wrapper">
    <div class="tab-nav">
        <button class="tab-btn active" onclick="openTab(event, 'support-form')">Request Support</button>
        <button class="tab-btn" onclick="openTab(event, 'admin-portal')">Staff Access</button>
    </div>

    <div class="portal-content">
        <?php if ($message_status): ?>
            <div class="msg-alert <?php echo $message_type; ?>"><?php echo $message_status; ?></div>
        <?php endif; ?>

        <div id="support-form" class="tab-pane active">
            <form method="POST">
                <div class="row-grid">
                    <div>
                        <label class="form-label">Full Name</label>
                        <input type="text" name="name" class="form-control" required placeholder="Name">
                    </div>
                    <div>
                        <label class="form-label">Contact Phone</label>
                        <input type="tel" name="phone" class="form-control" placeholder="04xx xxx xxx">
                    </div>
                </div>

                <div class="mb-4">
                    <label class="form-label">Email Address</label>
                    <input type="email" name="email" class="form-control" required placeholder="Email Address">
                </div>

                <div class="mb-4">
                    <label class="form-label">How can we help?</label>
                    <select name="service" class="form-control">
                        <option>PC Repairs & Upgrades</option>
                        <option>Smart Home Setup</option>
                        <option>Home Wi-Fi Solutions</option>
                        <option>Home Cybersecurity</option>
                        <option>Remote Support</option>
                        <option>Software Licensing</option>
                        <option>Business IT Support</option>
                        <option>Other</option>
                    </select>
                </div>

                <div class="mb-4">
                    <label class="form-label">Urgency</label>
                    <div class="urgency-wrap">
                        <div class="urgency-box">
                            <input type="radio" name="urgency" value="Low" id="u-low">
                            <label for="u-low" class="l">Low</label>
                        </div>
                        <div class="urgency-box">
                            <input type="radio" name="urgency" value="Medium" id="u-normal" checked>
                            <label for="u-normal" class="m">Normal</label>
                        </div>
                        <div class="urgency-box">
                            <input type="radio" name="urgency" value="High" id="u-high">
                            <label for="u-high" class="h">High</label>
                        </div>
                    </div>
                </div>

                <div class="mb-4">
                    <label class="form-label">Problem Summary</label>
                    <textarea name="summary" class="form-control" required rows="5" placeholder="Description of Issue"></textarea>
                </div>

                <button type="submit" name="submit_support" class="btn-main">Submit Support Request</button>
            </form>
        </div>

        <div id="admin-portal" class="tab-pane">
            <div class="admin-pane">
                <img src="https://cdn-icons-png.flaticon.com/512/3256/3256366.png" height="70" style="opacity:0.2; margin-bottom: 20px;">
                <h3>Staff Login</h3>
                <p>Authorized access for Blue Moon IT Administrators.</p>
                <a href="index.php" class="btn-outline">Login to Helpdesk</a>
            </div>
        </div>
    </div>
</div>

<footer class="main-footer">
    <div class="footer-container">
        <div class="footer-col brand">
            <img src="https://bluemoonit.com.au/assets/logo.png" height="40" style="margin-bottom:20px;">
            <p>Professional IT support for home users and small businesses in the Illawarra and surrounding regions.</p>
            <div class="social-icons">
                <a href="https://www.facebook.com/profile.php?id=61576388196114" target="_blank"><i class="fab fa-facebook-f"></i></a>
                <a href="https://www.linkedin.com/company/blue-moon-it-au" target="_blank"><i class="fab fa-linkedin-in"></i></a>
            </div>
        </div>
        <div class="footer-col">
            <h3>Services</h3>
            <ul>
                <li><a href="https://bluemoonit.com.au/services">PC Repairs & Upgrades</a></li>
                <li><a href="https://bluemoonit.com.au/services">Smart Home Setup</a></li>
                <li><a href="https://bluemoonit.com.au/services">Home Wi-Fi Solutions</a></li>
                <li><a href="https://bluemoonit.com.au/services">Home Cybersecurity</a></li>
                <li><a href="https://bluemoonit.com.au/services">View All Services</a></li>
            </ul>
        </div>
        <div class="footer-col">
            <h3>Quick Links</h3>
            <ul>
                <li><a href="https://bluemoonit.com.au/emergency">Emergency Help</a></li>
                <li><a href="https://bluemoonit.com.au/contact">Contact Us</a></li>
                <li><a href="https://bluemoonit.com.au/privacy-policy">Privacy Policy</a></li>
                <li><a href="https://bluemoonit.com.au/terms-of-service">Terms of Service</a></li>
            </ul>
        </div>
        <div class="footer-col">
            <h3>Hours</h3>
            <p>Monday: 8:30am - 5:00pm<br>
               Tuesday: 8:30am - 5:00pm<br>
               Wednesday: 8:30am - 5:00pm<br>
               Thursday: 8:30am - 5:00pm<br>
               Friday: 8:30am - 5:00pm</p>
        </div>
        <div class="footer-col">
            <h3>Contact Us</h3>
            <p><i class="fas fa-phone" style="color:var(--accent); margin-right:10px;"></i> <a href="tel:0283130444" style="color:rgba(255,255,255,0.7); text-decoration:none;">02 8313 0444</a></p>
            <p><i class="fas fa-envelope" style="color:var(--accent); margin-right:10px;"></i> <a href="mailto:support@bluemoonit.com.au" style="color:rgba(255,255,255,0.7); text-decoration:none;">support@bluemoonit.com.au</a></p>
        </div>
    </div>
    
    <div class="footer-bottom">
        <p>© 2026 Blue Moon IT. All rights reserved.</p>
        <p>Servicing Illawarra, Shoalhaven, Eurobodalla and Southern Highlands</p>
        <a href="https://abr.business.gov.au/ABN/View?abn=12159169631" target="_blank" class="abn">Australian Business Number (ABN) - 12 159 169 631</a>
    </div>
</footer>

<script>
function openTab(evt, tabId) {
    const panes = document.querySelectorAll('.tab-pane');
    const buttons = document.querySelectorAll('.tab-btn');
    
    panes.forEach(p => p.classList.remove('active'));
    buttons.forEach(b => b.classList.remove('active'));
    
    document.getElementById(tabId).classList.add('active');
    evt.currentTarget.classList.add('active');
}
</script>

</body>
</html>
