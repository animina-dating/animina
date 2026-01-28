# 13. Security Features

**Status:** Not Started

---

## 13.1 Input Validation
- Username: 2-15 chars, alphanumeric + dots/hyphens
- First name: 1-50 chars
- Last name: 1-50 chars
- Height: 80-225 cm
- Minimum partner age: >= 18
- Password: minimum 10 characters
- Phone number: validated and converted to E164 format using ex_phone_number library; stored in E164 format only

## 13.2 Uniqueness Constraints
- Email (case-insensitive)
- Username (case-insensitive)
- Mobile phone number

## 13.3 Access Control
- Route protection based on authentication state
- Role-based access (user vs admin)
- State-based visibility rules
- Automatic logout for banned/archived users
