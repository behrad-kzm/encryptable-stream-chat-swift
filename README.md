## Implement End-to-End Encrypted chat

This function will call when user publish new message:
```
    ComposerVC.Content.publishEncryptionHandler = { (text) in
        // apply encryption logic to the given text
        return encryptedText
    }
```

This function will call to decrypt each messages shown in the messageListVC, so you have to provide decryption there:
```
    messageListVC.publishDecryptionHandler = { (text, authorId) in
        // apply decryption logic with the given text and the authorId
        return decryptedText
    }
```

this is an example how I used these methodes with VirgilSecurity to implement an e3 chat:

```
class ChatsContainerVC: ChatChannelVC {
  
  func setup(){
    
      VirgilClient.shared.prepareUsersIfNeeded([userId, otherUserId])
      ComposerVC.Content.publishEncryptionHandler = { (text) in
        return try! VirgilClient.shared.encrypt(text, for: userId)
      }
      
      messageListVC.publishDecryptionHandler = { (text, authorId) in
        return try! VirgilClient.shared.decrypt(text, sender: authorId)
      }
  }
}
```
then just call `setup()` when you create an instance of `ChatsContainerVC` .

## Want more info?
visit the original repository and read the `README.md` file there
