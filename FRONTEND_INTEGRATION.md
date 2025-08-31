# DPR Chatbot - Frontend Integration Guide

## 🚀 Quick Start

- **Backend URL**: `http://localhost:3000`
- **All API endpoints start with**: `/api`

## 🔐 Authentication

### 1. User Login

```javascript
// Send login request
const response = await fetch("http://localhost:3000/api/auth/signin", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    email: "user@example.com",
    password: "password123",
  }),
});

const data = await response.json();
// Save this token for all other requests
localStorage.setItem("authToken", data.access);
```

### 2. Using the Token

```javascript
// Add this header to ALL other requests
const token = localStorage.getItem("authToken");
const headers = {
  "Content-Type": "application/json",
  Authorization: `Bearer ${token}`,
};
```

### 3. User Logout

```javascript
const response = await fetch("http://localhost:3000/api/auth/signout", {
  method: "POST",
  headers: {
    Authorization: `Bearer ${token}`,
  },
});
// Clear token after logout
localStorage.removeItem("authToken");
```

## �� Conversations

### 1. Create New Conversation

```javascript
const response = await fetch("http://localhost:3000/api/conversations", {
  method: "POST",
  headers: headers,
  body: JSON.stringify({
    title: "My DPR Discussion",
  }),
});

const data = await response.json();
// data.conversation.id - use this for messages
```

### 2. List User Conversations

```javascript
const response = await fetch("http://localhost:3000/api/conversations", {
  headers: headers,
});

const data = await response.json();
// data.conversations - array of conversations
```

### 3. Delete Conversation

```javascript
const response = await fetch(
  `http://localhost:3000/api/conversations/${conversationId}`,
  {
    method: "DELETE",
    headers: headers,
  }
);
```

## 💭 Messages

### 1. Get Conversation Messages

```javascript
const response = await fetch(
  `http://localhost:3000/api/conversations/${conversationId}/messages`,
  {
    headers: headers,
  }
);

const data = await response.json();
// data.messages - array of messages
```

### 2. Send Message to AI

```javascript
const response = await fetch(
  `http://localhost:3000/api/conversations/${conversationId}/messages`,
  {
    method: "POST",
    headers: headers,
    body: JSON.stringify({
      content: "What are the project timelines?",
    }),
  }
);

const data = await response.json();
// data.message - AI response with citations
```

## �� Response Formats

### Login Response

```json
{
  "success": true,
  "access": "jwt_token_here",
  "user": {
    "id": 1,
    "first_name": "John",
    "last_name": "Doe",
    "email": "user@example.com"
  }
}
```

### AI Message Response

```json
{
  "message": {
    "id": 3,
    "role": "assistant",
    "content": {
      "answer": "Based on the DPR documents...",
      "citations": ["Manipur_DPR.pdf"],
      "needs_consent": false
    }
  }
}
```

## ❌ Error Handling

### Common Errors

```javascript
if (!response.ok) {
  const errorData = await response.json();
  console.error("Error:", errorData.error);

  if (response.status === 401) {
    // Token expired - redirect to login
    localStorage.removeItem("authToken");
    // Redirect to login page
  }
}
```

## 🔧 Health Check

```javascript
// Check if backend is running
const response = await fetch("http://localhost:3000/api/health");
const data = await response.json();
// data.status should be "healthy"
```

## �� Important Notes

1. **Always include the Authorization header** with the token
2. **Save the token** after login
3. **Clear the token** after logout
4. **Handle 401 errors** by redirecting to login
5. **All API calls** need the token except `/api/auth/signin`

## 🚨 Common Issues

- **CORS errors**: Make sure backend is running on port 3000
- **401 errors**: Token expired or missing - redirect to login
- **404 errors**: Check the URL - all should start with `/api`