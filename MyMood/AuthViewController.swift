//
//  ViewController.swift
//  MyMood
//
//  Created by Юрий Бондарчук on 01/11/2017.
//  Copyright © 2017 Yury Bandarchuk. All rights reserved.
//

import UIKit
import Firebase
import MBProgressHUD

class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var fullNameTextField: UITextField!
    
    private var keyboardAdjusted = false
    private var visibleLocation: CGFloat!
    private var lastKeyboardOffset: CGFloat = 0.0
    private let teachersConfirmationCode = "iamnotstudent"
    private let studentsConfirmationCode = "student"
    
    private var allViews: Array<UIView> = Array<UIView>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        findAllViews(self.view)
        self.view.translatesAutoresizingMaskIntoConstraints = true
        visibleLocation = passwordTextField.frame.origin.y + passwordTextField.bounds.height + 60
        usernameTextField.delegate = self
        passwordTextField.delegate = self
        fullNameTextField.delegate = self
    }
    
    private func findAllViews(_ view: UIView) {
        allViews.append(view)
        view.translatesAutoresizingMaskIntoConstraints = true
        for otherView in view.subviews {
            findAllViews(otherView)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    private func updateErrorDescription(description: String) -> String {
        if description.contains("no user") {
            let result = "There is no user record corresponding to this identifier. Check username and password and try again."
            return result
        }
        return description
    }

    @IBAction func signInButtonClicked(_ sender: UIButton) {
        let email = (usernameTextField.text ?? "") + "@mymoodapp.com"
        let password = (passwordTextField.text ?? "")
        if (!Utils.isValidEmail(email: email)) {
            Utils.showAlertOnError(title: "Incorrect username", text: "The username you entered contains error, please, try again.", viewController: self)
            return
        }
        let username = usernameTextField.text!
        let auth = AuthLogic.sharedInstance()
        MBProgressHUD.showAdded(to: self.view, animated: true)
        auth.logInWith(email: email, password: password) { (user, error) in
            if let error = error {
                self.hideProgressBar()
                let message = self.updateErrorDescription(description: error.localizedDescription)
                Utils.showAlertOnError(title: "Error", text: message, viewController: self)
            } else {
                if let user = user {
                    let storage = Firestore.firestore()
                    storage.collection("users").whereField("user_id", isEqualTo: user.uid).getDocuments(completion: { (snapshot, error) in
                        self.hideProgressBar()
                        if let error = error {
                            Utils.showAlertOnError(title: "Error", text: error.localizedDescription, viewController: self)
                        } else {
                            for document in snapshot!.documents {
                                let data = document.data()
                                guard let userId = data["user_id"] as? String,
                                      let isAdmin = data["is_admin"] as? Int,
                                      let fullname = data["fullname"] as? String
                                    else { return }
                                Utils.setUserId(id: userId)
                                Utils.setFullname(name: fullname)
                                if isAdmin == 1 {
                                    Utils.makeCurrentUserAdmin()
                                } else {
                                    Utils.makeCurrentUserNonAdmin()
                                }
                            }
                        }
                        Utils.setUsername(name: username)
                        var nextSegueId: String = Segues.studentLoginSegue.rawValue
                        if Utils.isCurrentUserAdmin() {
                            nextSegueId = Segues.teacherLoginSegue.rawValue
                        }
                        self.performSegue(withIdentifier: nextSegueId, sender: self)
                    })
                }
            }
        }
    }
    
    @IBAction func signUpButtonClicked(_ sender: Any) {
        guard let fullname = fullNameTextField.text
            else {
                Utils.showAlertOnError(title: "Error", text: "Full Name could not be empty!", viewController: self)
                return
        }
        if fullname.characters.count < 2 {
            Utils.showAlertOnError(title: "Error", text: "Full Name is too short", viewController: self)
            return
        }
        let email = (usernameTextField.text ?? "") + "@mymoodapp.com"
        let password = (passwordTextField.text ?? "")
        if (!Utils.isValidEmail(email: email)) {
            Utils.showAlertOnError(title: "Incorrect username", text: "The username you entered contains error, please, try again.", viewController: self)
            return
        }
        let alertController = UIAlertController(title: "Confirmation", message: "Please, enter the teacher/student's access code", preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "Submit", style: .default) { (action) in
            guard let textFields = alertController.textFields else { return }
            if textFields.count > 0 {
                let textField = textFields.first!
                let code = textField.text!.lowercased()
                if code != self.teachersConfirmationCode && code != self.studentsConfirmationCode {
                    Utils.showAlertOnError(title: "Error", text: "Confirmation code is incorrect.", viewController: self)
                } else {
                    if code == self.teachersConfirmationCode {
                        self.registerTeacher(email: email, password: password, code: code)
                    } else if code == self.studentsConfirmationCode {
                        self.registerStudent(email: email, password: password, code: code)
                    }
                }
            }
        }
        alertController.addAction(alertAction)
        alertController.addTextField { (textField) in
            textField.placeholder = ""
        }
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func registerTeacher(email: String, password: String, code: String) {
        if code.lowercased() != self.teachersConfirmationCode {
            Utils.showAlertOnError(title: "Error", text: "Teacher's confirmation code is incorrect.", viewController: self)
        } else {
            let auth = AuthLogic.sharedInstance()
            MBProgressHUD.showAdded(to: self.view, animated: true)
            auth.registerWith(email: email, password: password, returnCallBack: { (user, error) in
                if let error = error {
                    self.hideProgressBar()
                    Utils.showAlertOnError(title: "Error", text: error.localizedDescription, viewController: self)
                } else {
                    if let user = user {
                        let storage = Firestore.firestore()
                        let currentUserData: [String: Any] = [
                            "user_id": user.uid,
                            "is_admin": 1,
                            "fullname": self.fullNameTextField.text!
                        ]
                        storage.collection("users").addDocument(data: currentUserData) { error in
                            self.hideProgressBar()
                            if let error = error {
                                Utils.showAlertOnError(title: "Error", text: error.localizedDescription, viewController: self)
                            } else {
                                Utils.showAlertOnError(title: "Success", text: "Your account has been created! You can now sign in using specified credentials.", viewController: self)
                            }
                        }
                        print("User created with id: \(user.uid)")
                    }
                }
            })
        }
    }
    
    
    private func registerStudent(email: String, password: String, code: String) {
        if code.lowercased() != self.studentsConfirmationCode {
            Utils.showAlertOnError(title: "Error", text: "Student's confirmation code is incorrect.", viewController: self)
        } else {
            let auth = AuthLogic.sharedInstance()
            MBProgressHUD.showAdded(to: self.view, animated: true)
            auth.registerWith(email: email, password: password, returnCallBack: { (user, error) in
                if let error = error {
                    self.hideProgressBar()
                    Utils.showAlertOnError(title: "Error", text: error.localizedDescription, viewController: self)
                } else {
                    if let user = user {
                        let storage = Firestore.firestore()
                        let currentUserData: [String: Any] = [
                            "user_id": user.uid,
                            "is_admin": 0,
                            "fullname": self.fullNameTextField.text!
                        ]
                        storage.collection("users").addDocument(data: currentUserData) { error in
                            self.hideProgressBar()
                            if let error = error {
                                Utils.showAlertOnError(title: "Error", text: error.localizedDescription, viewController: self)
                            } else {
                                Utils.showAlertOnError(title: "Success", text: "Your account has been created! You can now sign in using specified credentials.", viewController: self)
                            }
                        }
                        print("User created with id: \(user.uid)")
                    }
                }
            })
        }
    }
    
    private func hideProgressBar() {
        DispatchQueue.main.async {
            MBProgressHUD.hide(for: self.view, animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        if keyboardAdjusted == false {
            lastKeyboardOffset = getKeyboardHeight(notification: notification)
            UIView.animate(withDuration: 10.0, animations: {
               self.view.frame.origin.y -= self.lastKeyboardOffset
            })
            keyboardAdjusted = true
        }
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        if keyboardAdjusted == true {
            UIView.animate(withDuration: 10.0, animations: {
                self.view.frame.origin.y += self.lastKeyboardOffset
            })
            keyboardAdjusted = false
        }
    }
    
    func getKeyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        let needHeight = visibleLocation + keyboardSize.cgRectValue.height
        let result = max(0, needHeight - UIScreen.main.bounds.height + 30)
        return result
    }
    
    private enum Segues: String {
        case studentLoginSegue
        case teacherLoginSegue
    }
    
}

