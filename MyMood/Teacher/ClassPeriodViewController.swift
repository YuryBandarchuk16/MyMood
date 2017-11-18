//
//  ClassPeriodViewController.swift
//  MyMood
//
//  Created by Юрий Бондарчук on 10/11/2017.
//  Copyright © 2017 Yury Bandarchuk. All rights reserved.
//

import UIKit
import Firebase
import MBProgressHUD

class ClassPeriodViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var calendarImageView: UIImageView!
    
    public var dateToDisplay: String!

    private var classNames: Array<String> = Array<String>()
    private var classRefs: Array<DocumentReference> = Array<DocumentReference>()
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if dateToDisplay != nil {
            dateLabel.text = dateToDisplay
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dateToDisplay = Utils.getCurrentDateString()
        setupCalendarTap()
    }
    
    private func hideProgressBar() {
        DispatchQueue.main.async {
            MBProgressHUD.hide(for: self.view, animated: true)
        }
    }
    
    private func showProgressBar() {
        MBProgressHUD.showAdded(to: self.view, animated: true)
    }
    
    private var classesLoaded: Bool = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if (!classesLoaded) {
            loadClasses()
            classesLoaded = true
        }
    }
    
    private func loadClasses() {
        showProgressBar()
        let storage = Firestore.firestore()
        storage.collection("users").whereField("user_id", isEqualTo: Utils.getUserId()).getDocuments(completion: { (snapshot, error) in
            if let error = error {
                self.hideProgressBar()
                Utils.showAlertOnError(title: "Error", text: error.localizedDescription, viewController: self)
            } else {
                var ref: DocumentReference?
                for document in snapshot!.documents {
                    let data = document.data()
                    guard let userId = data["user_id"] as? String
                        else { return }
                    if userId == Utils.getUserId() {
                        ref = document.reference
                    }
                }
                if let docRef = ref {
                    docRef.collection("my_classes").getDocuments(completion: { (snapshot, error) in
                        if let error = error {
                            Utils.showAlertOnError(title: "Error", text: error.localizedDescription, viewController: self)
                        } else {
                            self.setAsyncTasks(amount: snapshot!.documents.count, callback: {
                                DispatchQueue.main.async {
                                    self.tableView.reloadData()
                                    self.hideProgressBar()
                                }
                            })
                            for document in snapshot!.documents {
                                let data = document.data()
                                guard let classId = data["class_id"] as? String
                                    else { return }
                                let storage = Firestore.firestore()
                                let currentClassRef = storage.collection("classes").document(classId)
                                currentClassRef.getDocument(completion: { (document, error) in
                                    if error != nil {
                                        return
                                    } else {
                                        guard let data = document?.data(),
                                            let className = data["class_name"] as? String
                                            else { return }
                                        print("YO, \(className)")
                                        self.classNames.append(className)
                                        self.classRefs.append(currentClassRef)
                                        self.oneAsyncTaskDone()
                                    }
                                })
                            }
                        }
                    })
                }
            }
        })
    }
    
    private var asyncTasks: Int = 0
    private var asyncTasksDoneCallback: (() -> Void)!
    
    private func setAsyncTasks(amount: Int, callback: @escaping (() -> Void)) {
        self.asyncTasks = amount
        self.asyncTasksDoneCallback = callback
    }
    
    private func oneAsyncTaskDone() {
        self.asyncTasks -= 1
        if (self.asyncTasks == 0) {
            self.asyncTasksDoneCallback()
        }
    }
    
    private func setupCalendarTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(calendarTapped))
        tap.numberOfTapsRequired = 1
        calendarImageView.isUserInteractionEnabled = true
        calendarImageView.addGestureRecognizer(tap)
    }
    
    @objc
    private func calendarTapped() {
        self.performSegue(withIdentifier: Segues.showCalendar.rawValue, sender: self)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.classNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "classCell") else {
            return UITableViewCell()
        }
        if let label = cell.viewWithTag(102) as? UILabel {
            label.text = self.classNames[indexPath.row]
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destionationViewController = segue.destination as? CalendarViewController {
            destionationViewController.previousViewController = self
        }
    }
    
    private enum Segues: String {
        case showCalendar
    }

}
