# DPR Chatbot - Frontend Integration Guide

## 🚀 Quick Start

- **Backend URL**: `http://localhost:3000`
- **All API endpoints start with**: `/api`
- **Important**: Always check the response format - all responses now follow the same pattern!

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

// NEW: Check if login was successful
if (data.success) {
  // Save this token for all other requests
  localStorage.setItem("authToken", data.access);
  console.log("Login successful!");
} else {
  console.error("Login failed:", data.error.message);
}
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

const data = await response.json();

// NEW: Check if logout was successful
if (data.success) {
  // Clear token after logout
  localStorage.removeItem("authToken");
  console.log("Logout successful!");
} else {
  console.error("Logout failed:", data.error.message);
}
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

// NEW: Check if creation was successful
if (data.success) {
  const conversation = data.data.conversation;
  console.log("Conversation created:", conversation.id);
  // Use conversation.id for messages
} else {
  console.error("Failed to create conversation:", data.error.message);
}
```

### 2. List User Conversations

```javascript
const response = await fetch("http://localhost:3000/api/conversations", {
  headers: headers,
});

const data = await response.json();

// NEW: Check if request was successful
if (data.success) {
  const conversations = data.data.conversations;
  const pagination = data.data.pagination;

  console.log("Conversations:", conversations);
  console.log("Has more conversations:", pagination.has_more);
} else {
  console.error("Failed to get conversations:", data.error.message);
}
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

const data = await response.json();

// NEW: Check if deletion was successful
if (data.success) {
  console.log("Conversation deleted successfully!");
} else {
  console.error("Failed to delete conversation:", data.error.message);
}
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

// NEW: Check if request was successful
if (data.success) {
  const messages = data.data.messages;
  const pagination = data.data.pagination;

  console.log("Messages:", messages);
  console.log("Has more messages:", pagination.has_more);
} else {
  console.error("Failed to get messages:", data.error.message);
}
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

// NEW: Check if request was successful
if (data.success) {
  const message = data.data.message;
  console.log("AI Response:", message);

  // Check if AI needs web search consent
  if (message.content.needs_consent) {
    console.log("AI needs consent for web search:", message.content.message);
    // Show consent modal to user
  }
} else {
  console.error("Failed to send message:", data.error.message);
}
```

## 📋 NEW: Standardized Response Format

### ✅ Success Response Format

**ALL successful responses now follow this pattern:**

```json
{
  "success": true,
  "data": {
    // Your actual data goes here
  },
  "message": "Optional success message"
}
```

### ❌ Error Response Format

**ALL error responses now follow this pattern:**

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "timestamp": "2025-08-30T...",
    "details": "Optional additional details"
  }
}
```

## 🔍 Response Examples

### Login Response

```json
{
  "success": true,
  "data": {
    "access": "jwt_token_here",
    "user": {
      "id": 1,
      "first_name": "John",
      "last_name": "Doe",
      "email": "user@example.com"
    }
  }
}
```

### Conversations Response

```json
{
  "success": true,
  "data": {
    "conversations": [
      {
        "id": 1,
        "title": "DPR Discussion",
        "message_count": 5,
        "created_at": "2025-08-30T...",
        "updated_at": "2025-08-30T..."
      }
    ],
    "pagination": {
      "has_more": true,
      "oldest_conversation_id": 1
    }
  }
}
```

### AI Message Response

```json
{
  "success": true,
  "data": {
    "message": {
      "id": 3,
      "role": "assistant",
      "content": {
        "answer": "Based on the DPR documents...",
        "citations": ["Manipur_DPR.pdf"],
        "needs_consent": false
      },
      "source": "dpr",
      "created_at": "2025-08-30T..."
    },
    "streaming": false
  }
}
```

## ❌ Error Handling (Updated)

### Common Error Codes

```javascript
if (!response.ok) {
  const errorData = await response.json();

  // NEW: Always check success field first
  if (!errorData.success) {
    const error = errorData.error;
    console.error("Error Code:", error.code);
    console.error("Error Message:", error.message);

    // Handle specific error types
    switch (error.code) {
      case "AUTHENTICATION_ERROR":
        // Token expired - redirect to login
        localStorage.removeItem("authToken");
        // Redirect to login page
        break;

      case "VALIDATION_ERROR":
        // Show validation errors to user
        console.error("Validation details:", error.details);
        break;

      case "CONVERSATION_NOT_FOUND":
        // Show "conversation not found" message
        break;

      default:
        // Show generic error message
        console.error("Unknown error:", error.message);
    }
  }
}
```

## 🔧 Health Check

```javascript
// Check if backend is running
const response = await fetch("http://localhost:3000/api/health");
const data = await response.json();

// NEW: Check the response format
if (data.status === "healthy") {
  console.log("Backend is running!");
} else {
  console.error("Backend is not healthy:", data);
}
```

## 🎯 Frontend Implementation Tips

### 1. Always Check Success Field

```javascript
// ✅ GOOD - Always check success first
const data = await response.json();
if (data.success) {
  // Handle success
  const result = data.data;
} else {
  // Handle error
  const error = data.error;
}

// ❌ BAD - Don't assume success
const data = await response.json();
const result = data.data; // This might not exist!
```

### 2. Handle Pagination

```javascript
// For conversations and messages
if (data.success) {
  const items = data.data.conversations; // or messages
  const pagination = data.data.pagination;

  if (pagination.has_more) {
    // Show "Load More" button
    // Use pagination.oldest_conversation_id for next request
  }
}
```

### 3. Handle AI Responses

```javascript
if (data.success) {
  const message = data.data.message;

  if (message.content.needs_consent) {
    // Show consent modal
    showConsentModal(message.content.message);
  } else {
    // Show AI response with citations
    showAIResponse(message.content.answer, message.content.citations);
  }
}
```

## 🚨 Common Issues & Solutions

### CORS Errors

- **Problem**: "No 'Access-Control-Allow-Origin' header"
- **Solution**: Make sure backend is running on port 3000

### 401 Errors

- **Problem**: "Not authorized" or "Invalid token"
- **Solution**: Token expired - redirect user to login page

### 404 Errors

- **Problem**: "Not found"
- **Solution**: Check URL - all should start with `/api`

### Response Format Errors

- **Problem**: "Cannot read property 'data' of undefined"
- **Solution**: Always check `data.success` before accessing `data.data`

## 📱 Example Vue.js Component

```javascript
export default {
  data() {
    return {
      conversations: [],
      loading: false,
      error: null,
    };
  },

  async mounted() {
    await this.loadConversations();
  },

  methods: {
    async loadConversations() {
      this.loading = true;
      this.error = null;

      try {
        const token = localStorage.getItem("authToken");
        const response = await fetch("/api/conversations", {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });

        const data = await response.json();

        if (data.success) {
          this.conversations = data.data.conversations;
        } else {
          this.error = data.error.message;
        }
      } catch (error) {
        this.error = "Failed to load conversations";
      } finally {
        this.loading = false;
      }
    },
  },
};
```

## 🎉 You're Ready!

With this guide, you can:

- ✅ **Login and logout** users
- ✅ **Create and manage** conversations
- ✅ **Send messages** and get AI responses
- ✅ **Handle errors** gracefully
- ✅ **Implement pagination** for better UX

**Remember**: Always check `data.success` first, then access `data.data` for your actual content!

## �� Need Help?

If you get stuck:

1. **Check the browser console** for error messages
2. **Verify the response format** matches what's shown above
3. **Make sure you're including** the Authorization header
4. **Test with Postman first** to make sure the backend works

**Good luck building an amazing frontend!** 🚀
